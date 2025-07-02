import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/application_package_factory.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/devices/device_manager.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/context_runner.dart' as fltool;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/github.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';
import 'package:flutterpi_tool/src/shutdown_hooks.dart';
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;
import 'package:meta/meta.dart';
import 'package:process/process.dart';

abstract class ExtensibleCommandBase extends FlutterCommand {
  @mustCallSuper
  void addArgs(ArgParser argParser) {}

  void validateNonOptionArgs();

  void validateArgs();

  @mustCallSuper
  void addContextOverrides(
    Map<Type, dynamic Function()> overrides,
  );
}

mixin DisplaySizeArg on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addOption(
      'display-size',
      help:
          'The physical size of the device display in millimeters. This is used to calculate the device pixel ratio.',
      valueHelp: 'width x height',
    );
    super.addArgs(argParser);
  }

  (int, int)? get displaySize {
    final size = stringArg('display-size');
    if (size == null) {
      return null;
    }

    final parts = size.split('x');
    if (parts.length != 2) {
      usageException(
        'Invalid --display-size: Expected two dimensions separated by "x".',
      );
    }

    try {
      return (int.parse(parts[0].trim()), int.parse(parts[1].trim()));
    } on FormatException {
      usageException(
        'Invalid --display-size: Expected both dimensions to be integers.',
      );
    }
  }
}

mixin DummyDisplayArgs on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addFlag(
      'dummy-display',
      help:
          'Simulate a dummy display. (Useful if no real display is connected)',
    );

    argParser.addOption(
      'dummy-display-size',
      help:
          'Simulate a dummy display with a specific size in physical pixels. (Useful if no real display is connected)',
      valueHelp: 'width x height',
    );
    super.addArgs(argParser);
  }

  bool get useDummyDisplay {
    final dummyDisplay = boolArg('dummy-display');
    final dummyDisplaySize = stringArg('dummy-display-size');
    if (dummyDisplay || dummyDisplaySize != null) {
      return true;
    }

    return false;
  }
}

mixin PixelRatioArg on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addOption(
      'pixel-ratio',
      help: 'The pixel ratio of the device display.',
      valueHelp: 'ratio',
    );
    super.addArgs(argParser);
  }

  double? get pixelRatio {
    final ratio = stringArg('pixel-ratio');
    if (ratio == null) {
      return null;
    }

    try {
      return double.parse(ratio);
    } on FormatException {
      usageException(
        'Invalid --pixel-ratio: Expected a floating point number.',
      );
    }
  }
}

mixin EngineFlavorFlags on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addFlag(
      'debug',
      help: 'Build for debug mode.',
      negatable: false,
    );

    argParser.addFlag(
      'profile',
      help: 'Build for profile mode.',
      negatable: false,
    );

    argParser.addFlag(
      'release',
      help: 'Build for release mode.',
      negatable: false,
    );

    argParser.addFlag(
      'debug-unoptimized',
      help:
          'Build for debug mode and use unoptimized engine. (For stepping through engine code)',
      negatable: false,
    );
    super.addArgs(argParser);
  }

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
        '',
      );
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
      return EngineFlavor.debug;
    }
  }

  @override
  BuildMode getBuildMode() {
    return getEngineFlavor().buildMode;
  }
}

mixin DebugSymbolsFlag on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addFlag(
      'debug-symbols',
      help: 'Include debug symbols in the output.',
      negatable: false,
    );
    super.addArgs(argParser);
  }

  bool get includeDebugSymbols => boolArg('debug-symbols');
}

mixin LocalFlutterpiArg on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addOption(
      'local-flutterpi',
      help: 'Use a locally-provided flutter-pi binary instead of a downloaded '
          'one.',
      valueHelp: 'path',
    );
    super.addArgs(argParser);
  }

  String? get localFlutterpiPath => stringArg('local-flutterpi');
}

mixin CustomCacheArgs on ExtensibleCommandBase {
  @override
  void addArgs(ArgParser argParser) {
    argParser.addOption(
      'github-artifacts-repo',
      help: 'The GitHub repository that provides the engine artifacts. If no '
          'run-id is specified, the release of this repository with tag '
          '"engine/<commit-hash>" will be used to look for the engine artifacts.',
      valueHelp: 'owner/repo',
    );

    argParser.addOption(
      'github-artifacts-runid',
      help: 'If this is specified, use the artifacts produced by this GitHub '
          'Actions workflow run ID to look for the engine artifacts.',
      valueHelp: 'runID',
    );

    argParser.addOption(
      'github-artifacts-engine-version',
      help: 'If a run-id is specified to download engine artifacts from a '
          'GitHub Actions run, this specifies the version of the engine '
          'artifacts that were built in the run. Specifying this will make '
          'sure the flutter SDK tries to use the right engine version. '
          'If this is not specified, the engine version will not be checked.',
      valueHelp: 'commit-hash',
    );

    argParser.addOption(
      'github-artifacts-auth-token',
      help: 'The GitHub personal access token to use for downloading engine '
          'artifacts from a private repository. This is required if the '
          'repository is private.',
      valueHelp: 'token',
    );
    super.addArgs(argParser);
  }

  MyGithub createGithub({http.Client? httpClient}) {
    httpClient ??= http.Client();

    final String? token;
    if (argParser.options.containsKey('github-artifacts-auth-token')) {
      token = stringArg('github-artifacts-auth-token');
    } else {
      token = null;
    }

    return MyGithub.caching(
      httpClient: httpClient,
      auth: token != null ? gh.Authentication.bearerToken(token) : null,
    );
  }

  FlutterpiCache createCustomCache({
    required FileSystem fs,
    required ShutdownHooks shutdownHooks,
    required Logger logger,
    required Platform platform,
    required MoreOperatingSystemUtils os,
    required FlutterProjectFactory projectFactory,
    required ProcessManager processManager,
    http.Client? httpClient,
  }) {
    final repo = stringArg('github-artifacts-repo');
    final runId = stringArg('github-artifacts-runid');
    final githubEngineHash = stringArg('github-artifacts-engine-version');

    if (runId != null) {
      return FlutterpiCache.fromWorkflow(
        hooks: shutdownHooks,
        logger: logger,
        fileSystem: fs,
        platform: platform,
        osUtils: os,
        projectFactory: projectFactory,
        processManager: processManager,
        repo: repo != null ? gh.RepositorySlug.full(repo) : null,
        runId: runId,
        availableEngineVersion: githubEngineHash,
        github: createGithub(httpClient: httpClient),
      );
    } else {
      return FlutterpiCache(
        hooks: shutdownHooks,
        logger: logger,
        fileSystem: fs,
        platform: platform,
        osUtils: os,
        projectFactory: projectFactory,
        processManager: processManager,
        repo: repo != null ? gh.RepositorySlug.full(repo) : null,
        github: createGithub(httpClient: httpClient),
      );
    }
  }

  @override
  void addContextOverrides(Map<Type, Function()> overrides) {
    overrides[Cache] = () => createCustomCache(
          fs: globals.fs,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
          platform: globals.platform,
          os: globals.os as MoreOperatingSystemUtils,
          projectFactory: globals.projectFactory,
          processManager: globals.processManager,
        );

    super.addContextOverrides(overrides);
  }
}

mixin SshRemoteNonOptionArg on ExtensibleCommandBase {
  @override
  void validateNonOptionArgs() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Expected SSH remote as non-option arg.', usage);
    }

    if (argResults!.rest.length > 1) {
      throw UsageException(
        'Too many non-option arguments specified: ${argResults!.rest}',
        usage,
      );
    }
  }

  String get sshRemote {
    switch (argResults!.rest) {
      case [String id]:
        return id;
      case [String _, ...]:
        throw UsageException(
          'Too many non-option arguments specified: ${argResults!.rest.skip(1)}',
          usage,
        );
      case []:
        throw UsageException('Expected device id as non-option arg.', usage);
      default:
        throw StateError(
          'Unexpected non-option argument list: ${argResults!.rest}',
        );
    }
  }

  String get sshHostname {
    final remote = sshRemote;
    return remote.contains('@') ? remote.split('@').last : remote;
  }

  String? get sshUser {
    final remote = sshRemote;
    return remote.contains('@') ? remote.split('@').first : null;
  }
}

mixin FlutterpiCommandMixin on FlutterCommand {
  final _contextOverrides = <Type, dynamic Function()>{};

  void addContextOverride<T>(dynamic Function() fn) {
    _contextOverrides[T] = fn;
  }

  void usesDeviceManager() {
    // The option is added to the arg parser as a global option in
    // FlutterpiToolCommandRunner.

    addContextOverride<DeviceManager>(
      () => FlutterpiToolDeviceManager(
        logger: globals.logger,
        platform: globals.platform,
        cache: globals.cache as FlutterpiCache,
        operatingSystemUtils: globals.os as MoreOperatingSystemUtils,
        sshUtils: SshUtils(
          processUtils: globals.processUtils,
          defaultRemote: '',
        ),
        flutterpiToolConfig: FlutterPiToolConfig(
          fs: globals.fs,
          logger: globals.logger,
          platform: globals.platform,
        ),
        deviceId: stringArg(FlutterGlobalOptions.kDeviceIdOption, global: true),
      ),
    );
  }

  Future<Set<FlutterpiTargetPlatform>> getDeviceBasedTargetPlatforms() async {
    final devices = await globals.deviceManager!.getDevices(
      filter: DeviceDiscoveryFilter(excludeDisconnected: false),
    );
    if (devices.isEmpty) {
      return {};
    }

    final targetPlatforms = {
      for (final device in devices.whereType<FlutterpiSshDevice>())
        await device.flutterpiTargetPlatform,
    };

    return targetPlatforms.expand((p) => [p, p.genericVariant]).toSet();
  }

  Future<void> populateCache({
    FlutterpiHostPlatform? hostPlatform,
    Set<FlutterpiTargetPlatform>? targetPlatforms,
    Set<EngineFlavor>? flavors,
    Set<BuildMode>? runtimeModes,
    bool? includeDebugSymbols,
  }) async {
    hostPlatform ??=
        switch ((globals.os as MoreOperatingSystemUtils).fpiHostPlatform) {
      FlutterpiHostPlatform.darwinARM64 => FlutterpiHostPlatform.darwinX64,
      FlutterpiHostPlatform.windowsARM64 => FlutterpiHostPlatform.windowsX64,
      FlutterpiHostPlatform other => other,
    };

    targetPlatforms ??= await getDeviceBasedTargetPlatforms();

    flavors ??= {getEngineFlavor()};

    runtimeModes ??= {getEngineFlavor().buildMode};

    includeDebugSymbols ??= getIncludeDebugSymbols();

    await globals.flutterpiCache.updateAll(
      {DevelopmentArtifact.universal},
      host: hostPlatform,
      flutterpiPlatforms: targetPlatforms,
      runtimeModes: runtimeModes,
      engineFlavors: flavors,
      includeDebugSymbols: includeDebugSymbols,
    );
  }

  @override
  void addBuildModeFlags({
    required bool verboseHelp,
    bool defaultToRelease = true,
    bool excludeDebug = false,
    bool excludeRelease = false,
  }) {
    throw UnsupportedError(
      'This method is not supported in Flutterpi commands.',
    );
  }

  @override
  bool get usingCISystem => false;

  @override
  String? get debugLogsDirectoryPath => null;

  Future<T> runWithContext<T>(FutureOr<T> Function() fn) async {
    return fltool.runInContext(
      fn,
      overrides: {
        TemplateRenderer: () => const MustacheTemplateRenderer(),
        FlutterpiCache: () => FlutterpiCache(
              hooks: globals.shutdownHooks,
              logger: globals.logger,
              fileSystem: globals.fs,
              platform: globals.platform,
              osUtils: globals.os as MoreOperatingSystemUtils,
              projectFactory: globals.projectFactory,
              processManager: globals.processManager,
              github: createGithub(
                httpClient: http.IOClient(
                  globals.httpClientFactory?.call() ?? HttpClient(),
                ),
              ),
            ),
        Cache: () => globals.flutterpiCache,
        OperatingSystemUtils: () => MoreOperatingSystemUtils(
              fileSystem: globals.fs,
              logger: globals.logger,
              platform: globals.platform,
              processManager: globals.processManager,
            ),
        Logger: createLogger,
        Artifacts: () => CachedArtifacts(
              fileSystem: globals.fs,
              platform: globals.platform,
              cache: globals.cache,
              operatingSystemUtils: globals.os,
            ),
        Usage: () => DisabledUsage(),
        FlutterPiToolConfig: () => FlutterPiToolConfig(
              fs: globals.fs,
              logger: globals.logger,
              platform: globals.platform,
            ),
        BuildTargets: () => const BuildTargetsImpl(),
        ApplicationPackageFactory: () => FlutterpiApplicationPackageFactory(),
        ..._contextOverrides,
      },
    );
  }

  @override
  Future<FlutterCommandResult> runCommand();

  @override
  Future<void> run() async {
    Cache.flutterRoot = await getFlutterRoot();

    return await runWithContext(() async {
      try {
        final result = await verifyThenRunCommand(null);

        await exitWithHooks(
          result.exitStatus == ExitStatus.success ? 0 : 1,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      } on ToolExit catch (e) {
        if (e.message != null) {
          globals.printError(e.message!);
        }

        await exitWithHooks(
          e.exitCode ?? 1,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      } on UsageException catch (e) {
        globals.printError(e.message);
        globals.printStatus(e.usage);

        await exitWithHooks(
          1,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      }
    });
  }
}
