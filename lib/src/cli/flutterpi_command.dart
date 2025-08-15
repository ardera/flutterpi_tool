import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/github.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;
import 'package:process/process.dart';

enum FilesystemLayout {
  flutterPi,
  metaFlutter;

  @override
  String toString() {
    return switch (this) {
      flutterPi => 'flutter-pi',
      metaFlutter => 'meta-flutter'
    };
  }

  static FilesystemLayout fromString(String string) {
    return switch (string) {
      'flutter-pi' => FilesystemLayout.flutterPi,
      'meta-flutter' => FilesystemLayout.metaFlutter,
      _ => throw ArgumentError.value(string, 'Unknown filesystem layout'),
    };
  }
}

mixin FlutterpiCommandMixin on fl.FlutterCommand {
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
    required fl.ShutdownHooks shutdownHooks,
    required fl.Logger logger,
    required fl.Platform platform,
    required MoreOperatingSystemUtils os,
    required fl.FlutterProjectFactory projectFactory,
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

  void usesSshRemoteNonOptionArg({bool mandatory = true}) {
    assert(mandatory);
  }

  void usesDisplaySizeArg() {
    argParser.addOption(
      'display-size',
      help:
          'The physical size of the device display in millimeters. This is used to calculate the device pixel ratio.',
      valueHelp: 'width x height',
    );
  }

  void usesDummyDisplayArg() {
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
  }

  void usesLocalFlutterpiExecutableArg({bool verboseHelp = false}) {
    argParser.addOption(
      'flutterpi-binary',
      help:
          'Use a custom, pre-built flutter-pi executable instead of download one from the Flutter-Pi CI.',
      valueHelp: 'path',
      hide: !verboseHelp,
    );
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

  (int, int)? get dummyDisplaySize {
    final size = stringArg('dummy-display-size');
    if (size == null) {
      return null;
    }

    final parts = size.split('x');
    if (parts.length != 2) {
      usageException(
        'Invalid --dummy-display-size: Expected two dimensions separated by "x".',
      );
    }

    try {
      return (int.parse(parts[0].trim()), int.parse(parts[1].trim()));
    } on FormatException {
      usageException(
        'Invalid --dummy-display-size: Expected both dimensions to be integers.',
      );
    }
  }

  bool get useDummyDisplay {
    final dummyDisplay = boolArg('dummy-display');
    final dummyDisplaySize = stringArg('dummy-display-size');
    if (dummyDisplay || dummyDisplaySize != null) {
      return true;
    }

    return false;
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

  final _contextOverrides = <Type, dynamic Function()>{};

  void addContextOverride<T>(dynamic Function() fn) {
    _contextOverrides[T] = fn;
  }

  void usesEngineFlavorOption() {
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
  }

  void usesDebugSymbolsOption() {
    argParser.addFlag(
      'debug-symbols',
      help: 'Include debug symbols in the output.',
      negatable: false,
    );
  }

  bool getIncludeDebugSymbols() {
    return boolArg('debug-symbols');
  }

  EngineFlavor getEngineFlavor() {
    // If we don't have any of the engine flavor options, default to debug.
    if (!argParser.options.containsKey('debug') &&
        !argParser.options.containsKey('profile') &&
        !argParser.options.containsKey('release') &&
        !argParser.options.containsKey('debug-unoptimized')) {
      return EngineFlavor.debug;
    }

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

  File? getLocalFlutterpiExecutable() {
    final path = stringArg('flutterpi-binary');
    if (path == null) {
      return null;
    }

    if (!globals.fs.isFileSync(path)) {
      usageException(
        'The specified flutter-pi binary does not exist, '
        'or is not a file: $path',
      );
    }

    return globals.fs.file(path);
  }

  void usesFilesystemLayoutArg({bool verboseHelp = false}) {
    argParser.addOption(
      'fs-layout',
      valueHelp: 'layout',
      help:
          'The filesystem layout of the built app bundle. Yocto (meta-flutter) '
          'uses a different filesystem layout for apps than flutter-pi normally '
          'accepts, so when trying to use flutterpi_tool with a device running '
          'a meta-flutter yocto image, the meta-flutter fs layout must be '
          'chosen instead.',
      allowed: ['flutter-pi', 'meta-flutter'],
      defaultsTo: 'flutter-pi',
      hide: !verboseHelp,
    );
  }

  FilesystemLayout get filesystemLayout => switch (stringArg('fs-layout')) {
        'flutter-pi' => FilesystemLayout.flutterPi,
        'meta-flutter' => FilesystemLayout.metaFlutter,
        _ => usageException(
            'Invalid --fs-layout: Expected "flutter-pi" or "meta-flutter".',
          ),
      };

  Future<Set<FlutterpiTargetPlatform>> getDeviceBasedTargetPlatforms() async {
    final devices = await globals.deviceManager!.getDevices(
      filter: fl.DeviceDiscoveryFilter(excludeDisconnected: false),
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
    Set<fl.BuildMode>? runtimeModes,
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
      {fl.DevelopmentArtifact.universal},
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
  fl.BuildMode getBuildMode() {
    return getEngineFlavor().buildMode;
  }

  @override
  bool get usingCISystem => false;

  @override
  String? get debugLogsDirectoryPath => null;

  Future<T> runWithContext<T>(FutureOr<T> Function() fn) async {
    return fl.context.run(
      body: fn,
      overrides: _contextOverrides,
    );
  }

  @override
  Future<fl.FlutterCommandResult> runCommand();

  @override
  Future<void> run() async {
    return await runWithContext(() async {
      await verifyThenRunCommand(null);
    });
  }
}
