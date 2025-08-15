// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';

import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/extended_environment.dart';
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';

class ReleaseBundleFlutterpiAssets extends CompositeTarget {
  ReleaseBundleFlutterpiAssets({
    required this.target,
    required this.layout,
    bool debugSymbols = false,
    bool forceBundleFlutterpi = false,
  }) : super([
          CopyFlutterAssets(
            layout: layout,
            buildMode: BuildMode.release,
          ),
          CopyIcudtl(layout: layout),
          CopyFlutterpiEngine(
            target: target,
            flavor: EngineFlavor.release,
            includeDebugSymbols: debugSymbols,
            layout: layout,
          ),
          if (layout == FilesystemLayout.flutterPi || forceBundleFlutterpi)
            CopyFlutterpiBinary(
              target: target,
              buildMode: BuildMode.release,
              layout: layout,
            ),
          FlutterpiAppElf(
            AotElfRelease(TargetPlatform.linux_arm64),
            layout: layout,
          ),
        ]);

  final FlutterpiTargetPlatform target;
  final FilesystemLayout layout;

  @override
  String get name => 'release_bundle_flutterpi_${target.shortName}_assets';
}

class ProfileBundleFlutterpiAssets extends CompositeTarget {
  ProfileBundleFlutterpiAssets({
    required this.target,
    bool debugSymbols = false,
    required FilesystemLayout layout,
    bool forceBundleFlutterpi = false,
  }) : super([
          CopyFlutterAssets(
            layout: layout,
            buildMode: BuildMode.profile,
          ),
          CopyIcudtl(layout: layout),
          CopyFlutterpiEngine(
            target: target,
            flavor: EngineFlavor.profile,
            includeDebugSymbols: debugSymbols,
            layout: layout,
          ),
          if (layout == FilesystemLayout.flutterPi || forceBundleFlutterpi)
            CopyFlutterpiBinary(
              target: target,
              buildMode: BuildMode.profile,
              layout: layout,
            ),
          FlutterpiAppElf(
            AotElfProfile(TargetPlatform.linux_arm64),
            layout: layout,
          ),
        ]);

  final FlutterpiTargetPlatform target;

  @override
  String get name => 'profile_bundle_flutterpi_${target.shortName}_assets';
}

class DebugBundleFlutterpiAssets extends CompositeTarget {
  DebugBundleFlutterpiAssets({
    required this.target,
    bool unoptimized = false,
    bool debugSymbols = false,
    required FilesystemLayout layout,
    bool forceBundleFlutterpi = false,
  }) : super([
          CopyFlutterAssets(
            layout: layout,
            buildMode: BuildMode.debug,
          ),
          CopyIcudtl(layout: layout),
          CopyFlutterpiEngine(
            target: target,
            flavor: unoptimized ? EngineFlavor.debugUnopt : EngineFlavor.debug,
            includeDebugSymbols: debugSymbols,
            layout: layout,
          ),
          if (layout == FilesystemLayout.flutterPi || forceBundleFlutterpi)
            CopyFlutterpiBinary(
              target: target,
              buildMode: BuildMode.debug,
              layout: layout,
            ),
        ]);

  final FlutterpiTargetPlatform target;

  @override
  String get name => 'debug_bundle_flutterpi_assets';
}

class CopyIcudtl extends Target {
  const CopyIcudtl({required this.layout});

  final FilesystemLayout layout;

  @override
  String get name => 'flutterpi_copy_icudtl';

  @override
  List<Source> get inputs => const <Source>[
        Source.artifact(Artifact.icuData),
      ];

  @override
  List<Source> get outputs => <Source>[
        switch (layout) {
          FilesystemLayout.flutterPi =>
            Source.pattern('{OUTPUT_DIR}/icudtl.dat'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/data/icudtl.dat'),
        },
      ];

  @override
  List<Target> get dependencies => [];

  @override
  Future<void> build(Environment environment) async {
    final icudtl = environment.fileSystem
        .file(environment.artifacts.getArtifactPath(Artifact.icuData));

    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('data'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = outputDir.childFile('icudtl.dat');
    icudtl.copySync(outputFile.path);
  }
}

extension _FileExecutableBits on File {
  (bool owner, bool group, bool other) getExecutableBits() {
    // ignore: constant_identifier_names
    const S_IXUSR = 00100, S_IXGRP = 00010, S_IXOTH = 00001;

    final stat = statSync();
    final mode = stat.mode;

    return (
      (mode & S_IXUSR) != 0,
      (mode & S_IXGRP) != 0,
      (mode & S_IXOTH) != 0
    );
  }
}

void fixupExePermissions(
  File input,
  File output, {
  required Platform platform,
  required Logger logger,
  required MoreOperatingSystemUtils os,
}) {
  if (platform.isLinux || platform.isMacOS) {
    final inputExeBits = input.getExecutableBits();
    final outputExeBits = output.getExecutableBits();

    if (outputExeBits != (true, true, true)) {
      if (inputExeBits == outputExeBits) {
        logger.printTrace(
          '${input.basename} in cache was not universally executable. '
          'Changing permissions...',
        );
      } else {
        logger.printTrace(
          'Copying ${input.basename} from cache to output directory did not preserve executable bit. '
          'Changing permissions...',
        );
      }

      os.chmod(output, 'ugo+x');
    }
  }
}

class CopyFlutterpiBinary extends Target {
  CopyFlutterpiBinary({
    required this.target,
    required this.buildMode,
    required this.layout,
  });

  final FlutterpiTargetPlatform target;
  final BuildMode buildMode;
  final FilesystemLayout layout;

  @override
  Future<void> build(Environment environment) async {
    final artifacts = environment.artifacts;
    if (artifacts is! FlutterpiArtifacts) {
      throw StateError(
        'Expected artifacts to be a FlutterpiArtifacts, '
        'but got ${artifacts.runtimeType}.',
      );
    }

    final file = artifacts
        .getFlutterpiArtifact(FlutterpiBinary(target: target, mode: buildMode));

    assert(file.fileSystem == environment.fileSystem);

    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('bin'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = outputDir.childFile('flutter-pi');
    file.copySync(outputFile.path);

    if (environment.platform.isLinux || environment.platform.isMacOS) {
      final inputExeBits = file.getExecutableBits();
      final outputExeBits = outputFile.getExecutableBits();

      if (outputExeBits != (true, true, true)) {
        if (inputExeBits == outputExeBits) {
          environment.logger.printTrace(
            'flutter-pi binary in cache was not universally executable. '
            'Changing permissions...',
          );
        } else {
          environment.logger.printTrace(
            'Copying flutter-pi binary from cache to output directory did not preserve executable bit. '
            'Changing permissions...',
          );
        }

        os.chmod(outputFile, 'ugo+x');
      }
    }
  }

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => <Source>[
        FlutterpiArtifactSource(
          FlutterpiBinary(target: target, mode: buildMode),
        ),
      ];

  @override
  String get name => 'copy_flutterpi';

  @override
  List<Source> get outputs => <Source>[
        switch (layout) {
          FilesystemLayout.flutterPi =>
            Source.pattern('{OUTPUT_DIR}/flutter-pi'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/bin/flutter-pi'),
        },
      ];
}

class CopyFlutterpiEngine extends Target {
  CopyFlutterpiEngine({
    required this.target,
    required this.flavor,
    required this.layout,
    this.includeDebugSymbols = false,
  })  : _engine = Engine(
          target: target,
          flavor: flavor,
        ),
        _debugSymbols = EngineDebugSymbols(
          target: target,
          flavor: flavor,
        );

  final FlutterpiTargetPlatform target;
  final EngineFlavor flavor;
  final bool includeDebugSymbols;
  final FilesystemLayout layout;

  final FlutterpiArtifact _engine;
  final FlutterpiArtifact _debugSymbols;

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => [
        FlutterpiArtifactSource(_engine),
        if (includeDebugSymbols) FlutterpiArtifactSource(_debugSymbols),
      ];

  @override
  String get name => 'copy_flutterpi_engine_${target.shortName}_$flavor';

  @override
  List<Source> get outputs => [
        switch (layout) {
          FilesystemLayout.flutterPi =>
            Source.pattern('{OUTPUT_DIR}/libflutter_engine.so'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/lib/libflutter_engine.so'),
        },
        if (includeDebugSymbols)
          switch (layout) {
            FilesystemLayout.flutterPi =>
              Source.pattern('{OUTPUT_DIR}/libflutter_engine.dbgsyms'),
            FilesystemLayout.metaFlutter =>
              Source.pattern('{OUTPUT_DIR}/lib/libflutter_engine.dbgsyms'),
          },
      ];

  @override
  Future<void> build(covariant ExtendedEnvironment environment) async {
    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('lib'),
    };

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = outputDir.childFile('libflutter_engine.so');

    final engine = environment.artifacts.getFlutterpiArtifact(_engine);

    engine.copySync(outputFile.path);

    fixupExePermissions(
      engine,
      outputFile,
      platform: environment.platform,
      logger: environment.logger,
      os: environment.operatingSystemUtils,
    );

    if (includeDebugSymbols) {
      final dbgsymsOutputFile =
          outputDir.childFile('libflutter_engine.dbgsyms');

      final dbgsyms = environment.artifacts.getFlutterpiArtifact(_debugSymbols);

      dbgsyms.copySync(dbgsymsOutputFile.path);

      fixupExePermissions(
        dbgsyms,
        dbgsymsOutputFile,
        platform: environment.platform,
        logger: environment.logger,
        os: environment.operatingSystemUtils,
      );
    }
  }
}

/// A wrapper for AOT compilation that copies app.so into the output directory.
class FlutterpiAppElf extends Target {
  /// Create a [FlutterpiAppElf] wrapper for [aotTarget].
  const FlutterpiAppElf(this.aotTarget, {required this.layout});

  /// The [AotElfBase] subclass that produces the app.so.
  final AotElfBase aotTarget;
  final FilesystemLayout layout;

  @override
  String get name => 'flutterpi_aot_bundle';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Source> get outputs => <Source>[
        switch (layout) {
          FilesystemLayout.flutterPi => Source.pattern('{OUTPUT_DIR}/app.so'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/lib/libapp.so'),
        },
      ];

  @override
  List<Target> get dependencies => <Target>[
        aotTarget,
      ];

  @override
  Future<void> build(covariant ExtendedEnvironment environment) async {
    final appElf = environment.buildDir.childFile('app.so');
    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('lib'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = switch (layout) {
      FilesystemLayout.flutterPi => outputDir.childFile('app.so'),
      FilesystemLayout.metaFlutter => outputDir.childFile('libapp.so'),
    };

    appElf.copySync(outputFile.path);

    fixupExePermissions(
      appElf,
      outputFile,
      platform: environment.platform,
      logger: logger,
      os: environment.operatingSystemUtils,
    );
  }
}

/// Copies the kernel_blob.bin to the output directory.
class CopyFlutterAssetsOld extends CopyFlutterBundle {
  const CopyFlutterAssetsOld();

  @override
  String get name => 'bundle_flutterpi_assets';
}

class CopyFlutterAssets extends Target {
  const CopyFlutterAssets({
    required this.layout,
    required this.buildMode,
  });

  final FilesystemLayout layout;
  final BuildMode buildMode;

  @override
  String get name => 'copy_flutterpi_assets_${layout}_$buildMode';

  @override
  List<Target> get dependencies => <Target>[
        const KernelSnapshot(),
      ];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
        ...IconTreeShaker.inputs,
      ];

  @override
  List<Source> get outputs => <Source>[
        if (buildMode.isJit)
          switch (layout) {
            FilesystemLayout.flutterPi =>
              Source.pattern('{OUTPUT_DIR}/kernel_blob.bin'),
            FilesystemLayout.metaFlutter => Source.pattern(
                '{OUTPUT_DIR}/data/flutter_assets/kernel_blob.bin',
              ),
          },
      ];

  @override
  List<String> get depfiles => const <String>['flutter_assets.d'];

  String getVersionInfo(Map<String, String> defines) {
    return FlutterProject.current().getVersionInfo();
  }

  @override
  Future<void> build(Environment environment) async {
    final buildMode = switch (environment.defines[kBuildMode]) {
      null => throw MissingDefineException(kBuildMode, name),
      String value => BuildMode.fromCliName(value),
    };

    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter => environment.outputDir
          .childDirectory('data')
          .childDirectory('flutter_assets'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    if (buildMode.isJit) {
      environment.buildDir
          .childFile('app.dill')
          .copySync(outputDir.childFile('kernel_blob.bin').path);
    }

    final versionInfo = getVersionInfo(environment.defines);

    final depfile = await copyAssets(
      environment,
      outputDir,

      // this is not really used internally,
      // copyAssets will just do something special if a web platform is
      // passed.
      //
      // So we don't need this to match the platform we're actually building
      // for.
      targetPlatform: TargetPlatform.linux_arm64,
      buildMode: buildMode,
      additionalContent: <String, DevFSContent>{
        'version.json': DevFSStringContent(versionInfo),
      },
    );

    environment.depFileService.writeToFile(
      depfile,
      environment.buildDir.childFile('flutter_assets.d'),
    );
  }
}
