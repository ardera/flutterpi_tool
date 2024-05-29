// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/build_targets.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:github/github.dart' as gh;
import 'package:unified_analytics/unified_analytics.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/fltool/context_runner.dart' as fltool;

import 'more_os_utils.dart';
import 'common.dart';

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
    outputDir: globals.fs.directory(assetDirPath),
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

Future<T> runWithContext<T>({
  required FutureOr<T> Function() runner,
  FlutterpiTargetPlatform? target,
  required FlutterpiCache Function() cacheFactory,
  bool verbose = false,
}) async {
  return fltool.runInContext(
    runner,
    overrides: {
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      Cache: cacheFactory,
      OperatingSystemUtils: () => MoreOperatingSystemUtils(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            processManager: globals.processManager,
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

Future<void> exitWithHooks(
  int code, {
  required ShutdownHooks shutdownHooks,
  required Logger logger,
}) async {
  // Run shutdown hooks before flushing logs
  await shutdownHooks.runShutdownHooks(logger);

  final completer = Completer<void>();

  // Give the task / timer queue one cycle through before we hard exit.
  Timer.run(() {
    try {
      logger.printTrace('exiting with code $code');
      io.exit(code);
    } catch (error, stackTrace) {
      // ignore: avoid_catches_without_on_clauses
      completer.completeError(error, stackTrace);
    }
  });

  return completer.future;
}

abstract class FlutterpiCommand extends FlutterCommand {
  void usesCustomCacheOption({bool verboseHelp = false}) {
    argParser.addOption(
      'github-artifacts-repo',
      help: 'The GitHub repository that provides the engine artifacts. If no '
          'run-id is specified, the release of this repository with tag '
          '"engine/<commit-hash>" will be used to look for the engine artifacts.',
      valueHelp: 'owner/repo',
      hide: !verboseHelp,
    );

    argParser.addOption(
      'github-artifacts-runid',
      help: 'If this is specified, use the artifacts produced by this GitHub '
          'Actions workflow run ID to look for the engine artifacts.',
      valueHelp: 'runID',
      hide: !verboseHelp,
    );

    argParser.addOption(
      'github-artifacts-engine-version',
      help: 'If a run-id is specified to download engine artifacts from a '
          'GitHub Actions run, this specifies the version of the engine '
          'artifacts that were built in the run. Specifying this will make '
          'sure the flutter SDK tries to use the right engine version. '
          'If this is not specified, the engine version will not be checked.',
      valueHelp: 'commit-hash',
      hide: !verboseHelp,
    );

    argParser.addOption(
      'github-artifacts-auth-token',
      help: 'The GitHub personal access token to use for downloading engine '
          'artifacts from a private repository. This is required if the '
          'repository is private.',
      valueHelp: 'token',
      hide: !verboseHelp,
    );
  }

  FlutterpiCache createCache({
    required FileSystem fs,
    required ShutdownHooks shutdownHooks,
    required Logger logger,
    required Platform platform,
    required MoreOperatingSystemUtils os,
    required FlutterProjectFactory projectFactory,
  }) {
    final repo = stringArg('github-artifacts-repo');
    final runId = stringArg('github-artifacts-runid');
    final githubEngineHash = stringArg('github-artifacts-engine-version');
    final token = stringArg('github-artifacts-auth-token');

    if (runId != null) {
      return GithubWorkflowRunFlutterpiCache(
        hooks: shutdownHooks,
        logger: logger,
        fileSystem: fs,
        platform: platform,
        osUtils: os,
        projectFactory: projectFactory,
        repo: repo != null ? gh.RepositorySlug.full(repo) : null,
        runId: runId,
        auth: token != null ? gh.Authentication.bearerToken(token) : null,
        availableEngineVersion: githubEngineHash,
      );
    } else {
      return GithubRepoReleasesFlutterpiCache(
        hooks: shutdownHooks,
        logger: logger,
        fileSystem: fs,
        platform: platform,
        osUtils: os,
        projectFactory: projectFactory,
        repo: repo != null ? gh.RepositorySlug.full(repo) : null,
        auth: token != null ? gh.Authentication.bearerToken(token) : null,
      );
    }
  }

  @override
  Future<FlutterCommandResult> runCommand() {
    // TODO: implement runCommand
    throw UnimplementedError();
  }
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
    usesCustomCacheOption(verboseHelp: verboseHelp);

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
      cacheFactory: () => createCache(
        fs: globals.fs,
        shutdownHooks: globals.shutdownHooks,
        logger: globals.logger,
        platform: globals.platform,
        os: globals.os as MoreOperatingSystemUtils,
        projectFactory: globals.projectFactory,
      ),
      runner: () async {
        try {
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

          await exitWithHooks(0, shutdownHooks: globals.shutdownHooks, logger: globals.logger);
        } on ToolExit catch (e) {
          if (e.message != null) {
            globals.printError(e.message!);
          }

          await exitWithHooks(e.exitCode ?? 1, shutdownHooks: globals.shutdownHooks, logger: globals.logger);
        } on UsageException catch (e) {
          globals.printError(e.message);
          globals.printStatus(e.usage);

          await exitWithHooks(1, shutdownHooks: globals.shutdownHooks, logger: globals.logger);
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

class PrecacheCommand extends FlutterpiCommand {
  PrecacheCommand({bool verboseHelp = false}) {
    usesCustomCacheOption(verboseHelp: verboseHelp);
  }

  @override
  String get name => 'precache';

  @override
  String get description => 'Populate the flutterpi_tool\'s cache of binary artifacts.';

  @override
  Future<int> run() async {
    Cache.flutterRoot = await getFlutterRoot();

    await runWithContext(
      verbose: boolArg('verbose', global: true),
      cacheFactory: () => createCache(
        fs: globals.fs,
        shutdownHooks: globals.shutdownHooks,
        logger: globals.logger,
        platform: globals.platform,
        os: globals.os as MoreOperatingSystemUtils,
        projectFactory: globals.projectFactory,
      ),
      runner: () async {
        try {
          final os = switch (globals.os) {
            MoreOperatingSystemUtils os => os,
            _ => throw StateError('Operating system utils is not an FPiOperatingSystemUtils'),
          };

          final host = switch (os.fpiHostPlatform) {
            FlutterpiHostPlatform.windowsARM64 => FlutterpiHostPlatform.windowsX64,
            FlutterpiHostPlatform.darwinARM64 => FlutterpiHostPlatform.darwinX64,
            FlutterpiHostPlatform other => other
          };

          // update the cached flutter-pi artifacts
          await flutterpiCache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
            host: host,
            flutterpiPlatforms: FlutterpiTargetPlatform.values.toSet(),
            engineFlavors: EngineFlavor.values.toSet(),
            includeDebugSymbols: true,
          );

          await exitWithHooks(0, shutdownHooks: globals.shutdownHooks, logger: globals.logger);
        } on ToolExit catch (e) {
          if (e.message != null) {
            globals.printError(e.message!);
          }

          await exitWithHooks(e.exitCode ?? 1, shutdownHooks: globals.shutdownHooks, logger: globals.logger);
        } on UsageException catch (e) {
          globals.printError(e.message);
          globals.printStatus(e.usage);

          await exitWithHooks(1, shutdownHooks: globals.shutdownHooks, logger: globals.logger);
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
      hide: true,
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

  @override
  void addCommand(Command<void> command) {
    if (command.name != 'help' && command is! FlutterpiCommand) {
      throw ArgumentError('Command is not a FlutterCommand: $command');
    }

    super.addCommand(command);
  }
}

Future<void> main(List<String> args) async {
  final verbose = args.contains('-v') || args.contains('--verbose') || args.contains('-vv');
  final powershellHelpIndex = args.indexOf('-?');
  if (powershellHelpIndex != -1) {
    args[powershellHelpIndex] = '-h';
  }

  final help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final verboseHelp = help && verbose;

  final runner = FlutterpiToolCommandRunner(verboseHelp: verboseHelp);

  runner.addCommand(BuildCommand(verboseHelp: verboseHelp));
  runner.addCommand(PrecacheCommand(verboseHelp: verboseHelp));

  runner.argParser
    ..addSeparator('Other options')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.');

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    print(e);
    io.exit(1);
  }
}
