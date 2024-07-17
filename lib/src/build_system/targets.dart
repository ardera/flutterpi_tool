// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';

import 'package:file/file.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

class ReleaseBundleFlutterpiAssets extends CompositeTarget {
  ReleaseBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiArtifactPaths artifactPaths,
    bool debugSymbols = false,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(flutterpiTargetPlatform,
              buildMode: BuildMode.release,
              hostPlatform: hostPlatform,
              artifactPaths: artifactPaths,
              includeDebugSymbols: debugSymbols,),
          CopyFlutterpiBinary(
            target: flutterpiTargetPlatform,
            buildMode: BuildMode.release,
          ),
          const FlutterpiAppElf(AotElfRelease(TargetPlatform.linux_arm64)),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name =>
      'release_bundle_flutterpi_${flutterpiTargetPlatform.shortName}_assets';
}

class ProfileBundleFlutterpiAssets extends CompositeTarget {
  ProfileBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiArtifactPaths artifactPaths,
    bool debugSymbols = false,
    String? flutterpiBinaryPathOverride,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(
            flutterpiTargetPlatform,
            buildMode: BuildMode.profile,
            hostPlatform: hostPlatform,
            artifactPaths: artifactPaths,
            includeDebugSymbols: debugSymbols,
          ),
          CopyFlutterpiBinary(
            target: flutterpiTargetPlatform,
            buildMode: BuildMode.profile,
          ),
          const FlutterpiAppElf(AotElfProfile(TargetPlatform.linux_arm64)),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name =>
      'profile_bundle_flutterpi_${flutterpiTargetPlatform.shortName}_assets';
}

class DebugBundleFlutterpiAssets extends CompositeTarget {
  DebugBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required FlutterpiHostPlatform hostPlatform,
    bool unoptimized = false,
    bool debugSymbols = false,
    required FlutterpiArtifactPaths artifactPaths,
    String? flutterpiBinaryPathOverride,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(
            flutterpiTargetPlatform,
            buildMode: BuildMode.debug,
            hostPlatform: hostPlatform,
            unoptimized: unoptimized,
            artifactPaths: artifactPaths,
            includeDebugSymbols: debugSymbols,
          ),
          CopyFlutterpiBinary(
            target: flutterpiTargetPlatform,
            buildMode: BuildMode.debug,
          ),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'debug_bundle_flutterpi_assets';
}

class CopyIcudtl extends Target {
  const CopyIcudtl();

  @override
  String get name => 'flutterpi_copy_icudtl';

  @override
  List<Source> get inputs => const <Source>[
        Source.artifact(Artifact.icuData),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/icudtl.dat'),
      ];

  @override
  List<Target> get dependencies => [];

  @override
  Future<void> build(Environment environment) async {
    final icudtl = environment.fileSystem
        .file(environment.artifacts.getArtifactPath(Artifact.icuData));
    final outputFile = environment.outputDir.childFile('icudtl.dat');
    icudtl.copySync(outputFile.path);
  }
}

class CopyFlutterpiBinary extends Target {
  CopyFlutterpiBinary({
    required this.target,
    required BuildMode buildMode,
  }) : flutterpiBuildType = buildMode == BuildMode.debug ? 'debug' : 'release';

  final FlutterpiTargetPlatform target;
  final String flutterpiBuildType;

  @override
  Future<void> build(Environment environment) async {
    final file = environment.cacheDir
        .childDirectory('artifacts')
        .childDirectory('flutter-pi')
        .childDirectory(target.triple)
        .childDirectory(flutterpiBuildType)
        .childFile('flutter-pi');

    final outputFile = environment.outputDir.childFile('flutter-pi');

    file.copySync(outputFile.path);
  }

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => <Source>[
        /// TODO: This should really be a Source.artifact(Artifact.flutterpiBinary)
        Source.pattern(
            '{CACHE_DIR}/artifacts/flutter-pi/${target.triple}/$flutterpiBuildType/flutter-pi',),
      ];

  @override
  String get name => 'copy_flutterpi';

  @override
  List<Source> get outputs => <Source>[
        Source.pattern('{OUTPUT_DIR}/flutter-pi'),
      ];
}

class CopyFlutterpiEngine extends Target {
  const CopyFlutterpiEngine(
    this.flutterpiTargetPlatform, {
    required BuildMode buildMode,
    required FlutterpiHostPlatform hostPlatform,
    bool unoptimized = false,
    this.includeDebugSymbols = false,
    required FlutterpiArtifactPaths artifactPaths,
  })  : _buildMode = buildMode,
        _hostPlatform = hostPlatform,
        _unoptimized = unoptimized,
        _artifactPaths = artifactPaths;

  final FlutterpiTargetPlatform flutterpiTargetPlatform;
  final BuildMode _buildMode;
  final FlutterpiHostPlatform _hostPlatform;
  final bool _unoptimized;
  final FlutterpiArtifactPaths _artifactPaths;
  final bool includeDebugSymbols;

  EngineFlavor get _engineFlavor => EngineFlavor(_buildMode, _unoptimized);

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => [
        _artifactPaths.getEngineSource(
          hostPlatform: _hostPlatform,
          target: flutterpiTargetPlatform,
          flavor: _engineFlavor,
        ),
        if (includeDebugSymbols)
          (_artifactPaths as FlutterpiArtifactPathsV2).getEngineDbgsymsSource(
            hostPlatform: _hostPlatform,
            target: flutterpiTargetPlatform,
            flavor: _engineFlavor,
          ),
      ];

  @override
  String get name =>
      'copy_flutterpi_engine_${flutterpiTargetPlatform.shortName}_$_buildMode${_unoptimized ? '_unopt' : ''}';

  @override
  List<Source> get outputs => [
        const Source.pattern('{OUTPUT_DIR}/libflutter_engine.so'),
        if (includeDebugSymbols)
          const Source.pattern('{OUTPUT_DIR}/libflutter_engine.dbgsyms'),
      ];

  @override
  Future<void> build(Environment environment) async {
    final outputFile = environment.outputDir.childFile('libflutter_engine.so');
    if (!outputFile.parent.existsSync()) {
      outputFile.parent.createSync(recursive: true);
    }

    _artifactPaths
        .getEngine(
          engineCacheDir: environment.cacheDir
              .childDirectory('artifacts')
              .childDirectory('engine'),
          hostPlatform: _hostPlatform,
          target: flutterpiTargetPlatform,
          flavor: _engineFlavor,
        )
        .copySync(outputFile.path);

    if (includeDebugSymbols) {
      final dbgsymsOutputFile =
          environment.outputDir.childFile('libflutter_engine.dbgsyms');
      if (!dbgsymsOutputFile.parent.existsSync()) {
        dbgsymsOutputFile.parent.createSync(recursive: true);
      }

      (_artifactPaths as FlutterpiArtifactPathsV2)
          .getEngineDbgsyms(
            engineCacheDir: environment.cacheDir
                .childDirectory('artifacts')
                .childDirectory('engine'),
            target: flutterpiTargetPlatform,
            flavor: _engineFlavor,
          )
          .copySync(dbgsymsOutputFile.path);
    }
  }
}

/// A wrapper for AOT compilation that copies app.so into the output directory.
class FlutterpiAppElf extends Target {
  /// Create a [FlutterpiAppElf] wrapper for [aotTarget].
  const FlutterpiAppElf(this.aotTarget);

  /// The [AotElfBase] subclass that produces the app.so.
  final AotElfBase aotTarget;

  @override
  String get name => 'flutterpi_aot_bundle';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/app.so'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        aotTarget,
      ];

  @override
  Future<void> build(Environment environment) async {
    final File outputFile = environment.buildDir.childFile('app.so');
    outputFile.copySync(environment.outputDir.childFile('app.so').path);
  }
}

/// Copies the kernel_blob.bin to the output directory.
class CopyFlutterAssets extends CopyFlutterBundle {
  const CopyFlutterAssets();

  @override
  String get name => 'bundle_flutterpi_assets';
}
