// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/build_targets.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/commands/command_runner.dart';
import 'package:flutterpi_tool/src/device/ssh_device.dart';
import 'package:unified_analytics/unified_analytics.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

import '../more_os_utils.dart';
import '../common.dart';

Future<FlutterpiAppBundle> buildFlutterpiApp({
  required String id,
  required FlutterpiHostPlatform host,
  required FlutterpiTargetPlatform target,
  required BuildInfo buildInfo,
  required FlutterpiArtifactPaths artifactPaths,
  FlutterProject? project,
  String? mainPath,
  String manifestPath = defaultManifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  Artifacts? artifacts,
  BuildSystem? buildSystem,
  bool unoptimized = false,
  bool includeDebugSymbols = false,
}) async {
  final buildDir = getBuildDirectory();
  final subDirs = 'flutter-pi/$target';
  final outPath = globals.fs.path.join(buildDir, subDirs);

  final outDir = globals.fs.directory(outPath);

  await buildFlutterpiBundle(
    host: host,
    target: target,
    buildInfo: buildInfo,
    artifactPaths: artifactPaths,
    outDir: outDir,
  );

  return PrebuiltFlutterpiAppBundle(
    id: id,
    name: id,
    displayName: id,
    directory: outDir,
  );
}

Future<void> buildFlutterpiBundle({
  required FlutterpiHostPlatform host,
  required FlutterpiTargetPlatform target,
  required BuildInfo buildInfo,
  required FlutterpiArtifactPaths artifactPaths,
  FlutterProject? project,
  String? mainPath,
  String manifestPath = defaultManifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  Directory? outDir,
  Artifacts? artifacts,
  BuildSystem? buildSystem,
  bool unoptimized = false,
  bool includeDebugSymbols = false,
}) async {
  project ??= FlutterProject.current();
  mainPath ??= defaultMainPath;
  depfilePath ??= defaultDepfilePath;
  buildSystem ??= globals.buildSystem;
  outDir ??= globals.fs.directory(getBuildDirectory());

  artifacts = OverrideGenSnapshotArtifacts.fromArtifactPaths(
    parent: artifacts ?? globals.artifacts!,
    engineCacheDir: flutterpiCache.getArtifactDirectory('engine'),
    host: host,
    target: target.genericVariant,
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
    outputDir: outDir,
    buildDir: project.dartTool.childDirectory('flutter_build'),
    cacheDir: globals.cache.getRoot(),
    flutterRootDir: globals.fs.directory(Cache.flutterRoot),
    engineVersion: globals.artifacts!.isLocalEngine ? null : globals.flutterVersion.engineRevision,
    analytics: NoOpAnalytics(),
    defines: <String, String>{
      if (includeDebugSymbols) kExtraGenSnapshotOptions: '--no-strip',

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

class BuildCommand extends FlutterpiCommand {
  static const archs = ['arm', 'arm64', 'x64'];

  static const cpus = ['generic', 'pi3', 'pi4'];

  BuildCommand({bool verboseHelp = false}) {
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
      ..addFlag('debug-symbols', help: 'Include flutter engine & app debug symbols.');

    // add --dart-define, --dart-define-from-file options
    usesDartDefineOption();
    usesTargetOption();
    usesCustomCache(verboseHelp: verboseHelp);

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
  Future<FlutterCommandResult> runCommand() async {
    final buildMode = getBuildMode();
    final flavor = getEngineFlavor();
    final debugSymbols = getIncludeDebugSymbols();
    final buildInfo = await getBuildInfo();

    final os = switch (globals.os) {
      MoreOperatingSystemUtils os => os,
      _ => throw StateError('Operating system utils is not an FPiOperatingSystemUtils'),
    };

    // for windows arm64, darwin arm64, we just use the x64 variant
    final host = switch (os.fpiHostPlatform) {
      FlutterpiHostPlatform.windowsARM64 => FlutterpiHostPlatform.windowsX64,
      FlutterpiHostPlatform.darwinARM64 => FlutterpiHostPlatform.darwinX64,
      FlutterpiHostPlatform other => other
    };

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
      host: host,
      offline: false,
      flutterpiPlatforms: {targetPlatform, targetPlatform.genericVariant},
      runtimeModes: {buildMode},
      engineFlavors: {flavor},
      includeDebugSymbols: debugSymbols,
    );

    // actually build the flutter bundle
    await buildFlutterpiBundle(
      host: host,
      target: targetPlatform,
      buildInfo: buildInfo,
      mainPath: targetFile,
      artifactPaths: flutterpiCache.artifactPaths,

      // for `--debug-unoptimized` build mode
      unoptimized: flavor.unoptimized,
      includeDebugSymbols: debugSymbols,
    );

    return FlutterCommandResult.success();
  }
}
