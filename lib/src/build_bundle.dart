// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_tools/executable.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/bundle.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/context_runner.dart' as fltool;
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/runner/flutter_command_runner.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

/// Copies the kernel_blob.bin to the output directory.
class CopyFlutterAssets extends CopyFlutterBundle {
  const CopyFlutterAssets();

  @override
  String get name => 'bundle_flutterpi_assets';
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

class CopyFlutterpiEngine extends Target {
  const CopyFlutterpiEngine(
    this.flutterpiTargetPlatform, {
    required BuildMode buildMode,
    required HostPlatform hostPlatform,
    bool unoptimized = false,
    this.includeDebugSymbols = false,
    required FlutterpiArtifactPaths artifactPaths,
  })  : _buildMode = buildMode,
        _hostPlatform = hostPlatform,
        _unoptimized = unoptimized,
        _artifactPaths = artifactPaths;

  final FlutterpiTargetPlatform flutterpiTargetPlatform;
  final BuildMode _buildMode;
  final HostPlatform _hostPlatform;
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
        if (includeDebugSymbols) const Source.pattern('{OUTPUT_DIR}/libflutter_engine.dbgsyms')
      ];

  @override
  Future<void> build(Environment environment) async {
    final outputFile = environment.outputDir.childFile('libflutter_engine.so');
    if (!outputFile.parent.existsSync()) {
      outputFile.parent.createSync(recursive: true);
    }

    _artifactPaths
        .getEngine(
          engineCacheDir: environment.cacheDir.childDirectory('artifacts').childDirectory('engine'),
          hostPlatform: _hostPlatform,
          target: flutterpiTargetPlatform,
          flavor: _engineFlavor,
        )
        .copySync(outputFile.path);

    if (includeDebugSymbols) {
      final dbgsymsOutputFile = environment.outputDir.childFile('libflutter_engine.dbgsyms');
      if (!dbgsymsOutputFile.parent.existsSync()) {
        dbgsymsOutputFile.parent.createSync(recursive: true);
      }

      (_artifactPaths as FlutterpiArtifactPathsV2)
          .getEngineDbgsyms(
            engineCacheDir: environment.cacheDir.childDirectory('artifacts').childDirectory('engine'),
            target: flutterpiTargetPlatform,
            flavor: _engineFlavor,
          )
          .copySync(dbgsymsOutputFile.path);
    }
  }
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
    final icudtl = environment.fileSystem.file(environment.artifacts.getArtifactPath(Artifact.icuData));
    final outputFile = environment.outputDir.childFile('icudtl.dat');
    icudtl.copySync(outputFile.path);
  }
}

class DebugBundleFlutterpiAssets extends CompositeTarget {
  DebugBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required HostPlatform hostPlatform,
    bool unoptimized = false,
    bool debugSymbols = false,
    required FlutterpiArtifactPaths artifactPaths,
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
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'debug_bundle_flutterpi_assets';
}

class ProfileBundleFlutterpiAssets extends CompositeTarget {
  ProfileBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required HostPlatform hostPlatform,
    required FlutterpiArtifactPaths artifactPaths,
    bool debugSymbols = false,
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
          const FlutterpiAppElf(AotElfProfile(TargetPlatform.linux_arm64)),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'profile_bundle_flutterpi_${flutterpiTargetPlatform.shortName}_assets';
}

class ReleaseBundleFlutterpiAssets extends CompositeTarget {
  ReleaseBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required HostPlatform hostPlatform,
    required FlutterpiArtifactPaths artifactPaths,
    bool debugSymbols = false,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(flutterpiTargetPlatform,
              buildMode: BuildMode.release,
              hostPlatform: hostPlatform,
              artifactPaths: artifactPaths,
              includeDebugSymbols: debugSymbols),
          const FlutterpiAppElf(AotElfRelease(TargetPlatform.linux_arm64)),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'release_bundle_flutterpi_${flutterpiTargetPlatform.shortName}_assets';
}

Future<String> getFlutterRoot() async {
  final pkgconfig = await findPackageConfigUri(io.Platform.script);
  pkgconfig!;

  final flutterToolsPath = pkgconfig.resolve(Uri.parse('package:flutter_tools/'))!.toFilePath();

  const dirname = path.dirname;

  return dirname(dirname(dirname(flutterToolsPath)));
}

Future<void> buildFlutterpiBundle({
  required HostPlatform host,
  required FlutterpiTargetPlatform target,
  required BuildInfo buildInfo,
  required FlutterpiArtifactPaths artifactPaths,
  FlutterProject? project,
  String? mainPath,
  String manifestPath = defaultManifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  String? assetDirPath,
  Artifacts? artifacts,
  BuildSystem? buildSystem,
  bool unoptimized = false,
  bool includeDebugSymbols = false,
}) async {
  project ??= FlutterProject.current();
  mainPath ??= defaultMainPath;
  depfilePath ??= defaultDepfilePath;
  assetDirPath ??= getAssetBuildDirectory();
  buildSystem ??= globals.buildSystem;

  artifacts = OverrideGenSnapshotArtifacts.fromArtifactPaths(
    parent: artifacts ?? globals.artifacts!,
    engineCacheDir: flutterpiCache.getArtifactDirectory('engine'),
    host: host,
    target: target,
    artifactPaths: artifactPaths,
  );

  // We can still build debug for non-generic platforms of course, the correct
  // (generic) target must be chosen in the caller in that case.
  if (!target.isGeneric && buildInfo.mode == BuildMode.debug) {
    throw ArgumentError.value(
      buildInfo,
      'buildInfo',
      'Non-generic targets are not supported for debug mode.',
    );
  }

  // If the precompiled flag was not passed, force us into debug mode.
  final environment = Environment(
    projectDir: project.directory,
    outputDir: globals.fs.directory(assetDirPath),
    buildDir: project.dartTool.childDirectory('flutter_build'),
    cacheDir: globals.cache.getRoot(),
    flutterRootDir: globals.fs.directory(Cache.flutterRoot),
    engineVersion: globals.artifacts!.isLocalEngine ? null : globals.flutterVersion.engineRevision,
    defines: <String, String>{
      // used by the KernelSnapshot target
      kTargetPlatform: getNameForTargetPlatform(TargetPlatform.linux_arm64),
      kTargetFile: mainPath,
      kDeferredComponents: 'false',
      ...buildInfo.toBuildSystemEnvironment(),

      // The flutter_tool computes the `.dart_tool/` subdir name from the
      // build environment hash.
      // Adding a flutterpi-target entry here forces different subdirs for
      // different target platforms.
      //
      // If we don't have this, the flutter tool will happily reuse as much as
      // it can, and it determines it can reuse the `app.so` from (for example)
      // an arm build with an arm64 build, leading to errors.
      'flutterpi-target': target.shortName,
      'unoptimized': unoptimized.toString(),
      'debug-symbols': includeDebugSymbols.toString(),
    },
    artifacts: artifacts,
    fileSystem: globals.fs,
    logger: globals.logger,
    processManager: globals.processManager,
    usage: globals.flutterUsage,
    platform: globals.platform,
    generateDartPluginRegistry: true,
  );

  final buildTarget = switch (buildInfo.mode) {
    BuildMode.debug => DebugBundleFlutterpiAssets(
        flutterpiTargetPlatform: target,
        hostPlatform: host,
        unoptimized: unoptimized,
        artifactPaths: artifactPaths,
        debugSymbols: includeDebugSymbols,
      ),
    BuildMode.profile => ProfileBundleFlutterpiAssets(
        flutterpiTargetPlatform: target,
        hostPlatform: host,
        artifactPaths: artifactPaths,
        debugSymbols: includeDebugSymbols,
      ),
    BuildMode.release => ReleaseBundleFlutterpiAssets(
        flutterpiTargetPlatform: target,
        hostPlatform: host,
        artifactPaths: artifactPaths,
        debugSymbols: includeDebugSymbols,
      ),
    _ => throwToolExit('Unsupported build mode: ${buildInfo.mode}'),
  };

  final status = globals.logger.startProgress('Building Flutter-Pi bundle...');

  try {
    final result = await buildSystem.build(buildTarget, environment);
    if (!result.success) {
      for (final measurement in result.exceptions.values) {
        globals.printError(
          'Target ${measurement.target} failed: ${measurement.exception}',
          stackTrace: measurement.fatal ? measurement.stackTrace : null,
        );
      }

      throwToolExit('Failed to build bundle.');
    }

    final depfile = Depfile(result.inputFiles, result.outputFiles);
    final outputDepfile = globals.fs.file(depfilePath);
    if (!outputDepfile.parent.existsSync()) {
      outputDepfile.parent.createSync(recursive: true);
    }

    final depfileService = DepfileService(
      fileSystem: globals.fs,
      logger: globals.logger,
    );
    depfileService.writeToFile(depfile, outputDepfile);
  } finally {
    status.cancel();
  }

  return;
}

Future<T> runWithContext<T>({
  required FutureOr<T> Function() runner,
  FlutterpiTargetPlatform? target,
  bool verbose = false,
}) async {
  return fltool.runInContext(
    runner,
    overrides: {
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      Cache: () => FlutterpiCache(
            logger: globals.logger,
            fileSystem: globals.fs,
            platform: globals.platform,
            osUtils: globals.os,
            projectFactory: globals.projectFactory,
            hooks: globals.shutdownHooks,
          ),
      OperatingSystemUtils: () => TarXzCompatibleOsUtils(
            os: OperatingSystemUtils(
              fileSystem: globals.fs,
              logger: globals.logger,
              platform: globals.platform,
              processManager: globals.processManager,
            ),
            processUtils: ProcessUtils(
              processManager: globals.processManager,
              logger: globals.logger,
            ),
          ),
      Logger: () {
        final factory = LoggerFactory(
          outputPreferences: globals.outputPreferences,
          terminal: globals.terminal,
          stdio: globals.stdio,
        );

        return factory.createLogger(
          daemon: false,
          machine: false,
          verbose: verbose,
          prefixedErrors: false,
          windows: globals.platform.isWindows,
        );
      },
      Artifacts: () => CachedArtifacts(
            fileSystem: globals.fs,
            platform: globals.platform,
            cache: globals.cache,
            operatingSystemUtils: globals.os,
          ),
      Usage: () => DisabledUsage()
    },
  );
}

Future<void> exitWithHooks(int code, {required ShutdownHooks shutdownHooks}) async {
  // Run shutdown hooks before flushing logs
  await shutdownHooks.runShutdownHooks(globals.logger);

  final completer = Completer<void>();

  // Give the task / timer queue one cycle through before we hard exit.
  Timer.run(() {
    try {
      globals.printTrace('exiting with code $code');
      io.exit(code);
    } catch (error, stackTrace) {
      // ignore: avoid_catches_without_on_clauses
      completer.completeError(error, stackTrace);
    }
  });

  return completer.future;
}

Never exitWithUsage(ArgParser parser, {String? errorMessage, int exitCode = 1}) {
  if (errorMessage != null) {
    print(errorMessage);
  }

  print('');
  print('Usage:');
  print('  flutterpi-tool [options...]');
  print('');
  print(parser.usage);
  io.exit(exitCode);
}

class BuildCommand extends FlutterCommand {
  static const archs = ['arm', 'arm64', 'x64'];

  static const cpus = ['generic', 'pi3', 'pi4'];

  BuildCommand() {
    argParser
      ..addSeparator('Runtime mode options (Defaults to debug. At most one can be specified)')
      ..addFlag('debug', negatable: false, help: 'Build for debug mode.')
      ..addFlag('profile', negatable: false, help: 'Build for profile mode.')
      ..addFlag('release', negatable: false, help: 'Build for release mode.')
      ..addFlag(
        'debug-unoptimized',
        negatable: false,
        help: 'Build for debug mode and use unoptimized engine. (For stepping through engine code)',
      )
      ..addSeparator('Build options')
      ..addFlag(
        'tree-shake-icons',
        help: 'Tree shake icon fonts so that only glyphs used by the application remain.',
      )
      ..addFlag('debug-symbols', help: 'Include flutter engine debug symbols file.');

    // add --dart-define, --dart-define-from-file options
    usesDartDefineOption();
    usesTargetOption();

    argParser
      ..addSeparator('Target options')
      ..addOption(
        'arch',
        allowed: archs,
        defaultsTo: 'arm',
        help: 'The target architecture to build for.',
        valueHelp: 'target arch',
        allowedHelp: {
          'arm': 'Build for 32-bit ARM. (armv7-linux-gnueabihf)',
          'arm64': 'Build for 64-bit ARM. (aarch64-linux-gnu)',
          'x64': 'Build for x86-64. (x86_64-linux-gnu)',
        },
      )
      ..addOption(
        'cpu',
        allowed: cpus,
        defaultsTo: 'generic',
        help:
            'If specified, uses an engine tuned for the given CPU. An engine tuned for one CPU will likely not work on other CPUs.',
        valueHelp: 'target cpu',
        allowedHelp: {
          'generic':
              'Don\'t use a tuned engine. The generic engine will work on all CPUs of the specified architecture.',
          'pi3':
              'Use a Raspberry Pi 3 tuned engine. Compatible with arm and arm64. (-mcpu=cortex-a53+nocrypto -mtune=cortex-a53)',
          'pi4':
              'Use a Raspberry Pi 4 tuned engine. Compatible with arm and arm64. (-mcpu=cortex-a72+nocrypto -mtune=cortex-a72)',
        },
      );
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Builds a flutter-pi asset bundle.';

  @override
  FlutterpiToolCommandRunner? get runner => super.runner as FlutterpiToolCommandRunner;

  EngineFlavor get defaultFlavor => EngineFlavor.debug;

  EngineFlavor getEngineFlavor() {
    final debug = boolArg('debug');
    final profile = boolArg('profile');
    final release = boolArg('release');
    final debugUnopt = boolArg('debug-unoptimized');

    final flags = [debug, profile, release, debugUnopt];
    if (flags.where((flag) => flag).length > 1) {
      throw UsageException(
          'Only one of "--debug", "--profile", "--release", '
              'or "--debug-unoptimized" can be specified.',
          '');
    }

    if (debug) {
      return EngineFlavor.debug;
    } else if (profile) {
      return EngineFlavor.profile;
    } else if (release) {
      return EngineFlavor.release;
    } else if (debugUnopt) {
      return EngineFlavor.debugUnopt;
    } else {
      return defaultFlavor;
    }
  }

  int exitWithUsage({int exitCode = 1, String? errorMessage, String? usage}) {
    if (errorMessage != null) {
      print(errorMessage);
    }

    if (usage != null) {
      print(usage);
    } else {
      printUsage();
    }
    return exitCode;
  }

  @override
  BuildMode getBuildMode() {
    return getEngineFlavor().buildMode;
  }

  bool getIncludeDebugSymbols() {
    return boolArg('debug-symbols');
  }

  FlutterpiTargetPlatform getTargetPlatform() {
    return switch ((stringArg('arch'), stringArg('cpu'))) {
      ('arm', 'generic') => FlutterpiTargetPlatform.genericArmV7,
      ('arm', 'pi3') => FlutterpiTargetPlatform.pi3,
      ('arm', 'pi4') => FlutterpiTargetPlatform.pi4,
      ('arm64', 'generic') => FlutterpiTargetPlatform.genericAArch64,
      ('arm64', 'pi3') => FlutterpiTargetPlatform.pi3_64,
      ('arm64', 'pi4') => FlutterpiTargetPlatform.pi4_64,
      ('x64', 'generic') => FlutterpiTargetPlatform.genericX64,
      (final arch, final cpu) => throw UsageException(
          'Unsupported target arch & cpu combination: architecture "$arch" is not supported for cpu "$cpu"',
          usage,
        ),
    };
  }

  @override
  Future<void> run() async {
    Cache.flutterRoot = await getFlutterRoot();

    await runWithContext(
      target: getTargetPlatform(),
      verbose: boolArg('verbose', global: true),
      runner: () async {
        try {
          final buildMode = getBuildMode();
          final flavor = getEngineFlavor();
          final debugSymbols = getIncludeDebugSymbols();
          final buildInfo = await getBuildInfo();

          var targetPlatform = getTargetPlatform();

          if (buildMode == BuildMode.debug && !targetPlatform.isGeneric) {
            globals.logger.printTrace(
              'Non-generic target platform ($targetPlatform) is not supported '
              'for debug mode, using generic variant '
              '${targetPlatform.genericVariant}.',
            );
            targetPlatform = targetPlatform.genericVariant;
          }

          // update the cached flutter-pi artifacts
          await flutterpiCache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
            flutterpiPlatforms: {targetPlatform, targetPlatform.genericVariant},
            runtimeModes: {buildMode},
            engineFlavors: {flavor},
            includeDebugSymbols: debugSymbols,
          );

          if (debugSymbols && flutterpiCache.artifactPaths is! FlutterpiArtifactPathsV2) {
            throwToolExit('Debug symbols are only supported since flutter 3.16.3.');
          }

          // actually build the flutter bundle
          await buildFlutterpiBundle(
            host: getCurrentHostPlatform(),
            target: targetPlatform,
            buildInfo: buildInfo,
            mainPath: targetFile,
            artifactPaths: flutterpiCache.artifactPaths,

            // for `--debug-unoptimized` build mode
            unoptimized: flavor.unoptimized,
            includeDebugSymbols: debugSymbols,
          );

          await globals.shutdownHooks.runShutdownHooks(globals.logger);
        } on ToolExit catch (e) {
          if (e.message != null) {
            globals.printError(e.message!);
          }

          return exitWithHooks(e.exitCode ?? 1, shutdownHooks: globals.shutdownHooks);
        }
      },
    );
  }

  @override
  Future<FlutterCommandResult> runCommand() {
    // TODO: implement runCommand
    throw UnimplementedError();
  }
}

class PrecacheCommand extends Command<void> {
  @override
  String get name => 'precache';

  @override
  String get description => 'Populate the flutterpi_tool\'s cache of binary artifacts.';

  @override
  Future<int> run() async {
    Cache.flutterRoot = await getFlutterRoot();

    await runWithContext(
      verbose: globalResults!['verbose'],
      runner: () async {
        try {
          // update the cached flutter-pi artifacts
          await flutterpiCache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
            flutterpiPlatforms: FlutterpiTargetPlatform.values.toSet(),
            engineFlavors: EngineFlavor.values.toSet(),
            includeDebugSymbols: true,
          );

          await globals.shutdownHooks.runShutdownHooks(globals.logger);
        } on ToolExit catch (e) {
          if (e.message != null) {
            globals.printError(e.message!);
          }

          return exitWithHooks(e.exitCode ?? 1, shutdownHooks: globals.shutdownHooks);
        }
      },
    );

    return 0;
  }
}

class FlutterpiToolCommandRunner extends CommandRunner<void> implements FlutterCommandRunner {
  FlutterpiToolCommandRunner({bool verboseHelp = false})
      : super(
          'flutterpi_tool',
          'A tool to make development & distribution of flutter-pi apps easier.',
          usageLineLength: 120,
        ) {
    argParser.addOption(
      FlutterGlobalOptions.kPackagesOption,
      hide: !verboseHelp,
      help: 'Path to your "package_config.json" file.',
    );
  }

  @override
  String get usageFooter => '';

  @override
  List<Directory> getRepoPackages() {
    throw UnimplementedError();
  }

  @override
  List<String> getRepoRoots() {
    throw UnimplementedError();
  }
}

Future<void> main(List<String> args) async {
  final runner = FlutterpiToolCommandRunner();

  runner.addCommand(BuildCommand());
  runner.addCommand(PrecacheCommand());

  runner.argParser
    ..addSeparator('Other options')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.');

  try {
    await runner.run(args);
    io.exitCode = 0;
  } on UsageException catch (e) {
    print(e);
    io.exitCode = 1;
  }
}
