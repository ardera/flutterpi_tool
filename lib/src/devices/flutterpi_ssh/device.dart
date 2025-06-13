import 'dart:async';
import 'dart:io';

import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

abstract class FlutterpiAppBundle extends ApplicationPackage {
  FlutterpiAppBundle({
    required super.id,
    required this.name,
    required this.displayName,
  });

  @override
  final String name;

  @override
  final String displayName;
}

class BuildableFlutterpiAppBundle extends FlutterpiAppBundle {
  BuildableFlutterpiAppBundle({
    required String id,
    required String name,
    required String displayName,
  }) : super(id: id, name: name, displayName: displayName);
}

class PrebuiltFlutterpiAppBundle extends FlutterpiAppBundle {
  PrebuiltFlutterpiAppBundle({
    required String id,
    required String name,
    required String displayName,
    required this.directory,
    required this.binaries,
  }) : super(id: id, name: name, displayName: displayName);

  final Directory directory;
  final List<File> binaries;
}

class _RunningApp {
  _RunningApp({
    required this.app,
    required this.sshProcess,
    required this.logReader,
    required this.sshUtils,
    required this.os,
  });

  final FlutterpiAppBundle app;
  final Process sshProcess;
  final DeviceLogReader logReader;
  final SshUtils sshUtils;
  final MoreOperatingSystemUtils os;

  Future<bool> _stopSSH({Duration timeout = const Duration(seconds: 5)}) async {
    sshProcess.kill(ProcessSignal.sigint);
    try {
      await sshProcess.exitCode.timeout(timeout);
      return true;
    } on TimeoutException catch (_) {}

    sshProcess.kill(ProcessSignal.sigterm);
    try {
      await sshProcess.exitCode.timeout(timeout);
      return true;
    } on TimeoutException catch (_) {}

    return false;
  }

  Future<bool> stop({Duration timeout = const Duration(seconds: 5)}) async {
    logReader.dispose();

    final sshStopResult = await _stopSSH(timeout: timeout);

    if (os.fpiHostPlatform.isWindows || !sshStopResult) {
      // On windows, forcing ssh to allocate a PTY (so the flutter-pi process
      // receives a SIGHUP on ssh exit and quits automatically) might not always
      // work.
      //
      // So let's just kill every flutter-pi on the remote on exit.
      final result = await sshUtils.runSsh(
        command: 'killall flutter-pi',
        timeout: timeout,
      );
      if (result.exitCode == 0) {
        return true;
      }
    } else {
      return true;
    }

    globals.printWarning('Could not terminate app on remote device.');
    return false;
  }
}

class FlutterpiArgs {
  const FlutterpiArgs({
    this.explicitDisplaySizeMillimeters,
    this.useDummyDisplay = false,
    this.dummyDisplaySize,
  });

  final (int, int)? explicitDisplaySizeMillimeters;
  final bool useDummyDisplay;
  final (int, int)? dummyDisplaySize;
}

class FlutterpiSshDevice extends Device {
  FlutterpiSshDevice({
    required String id,
    required this.name,
    required this.sshUtils,
    required String? remoteInstallPath,
    required this.logger,
    required this.os,
    required this.cache,
    this.args = const FlutterpiArgs(),
  })  : remoteInstallPath = remoteInstallPath ?? '/tmp/',
        super(
          id,
          category: Category.mobile,
          platformType: PlatformType.custom,
          ephemeral: false,
          logger: logger,
        );

  final SshUtils sshUtils;
  final String remoteInstallPath;
  final Logger logger;
  final FlutterpiCache cache;
  final MoreOperatingSystemUtils os;
  final FlutterpiArgs args;

  final runningApps = <String, _RunningApp>{};
  final logReaders = <String, CustomDeviceLogReader>{};
  final globalLogReader = CustomDeviceLogReader('FlutterPi');

  String _getRemoteInstallPath(FlutterpiAppBundle bundle) {
    return path.posix.join(remoteInstallPath, bundle.id);
  }

  @visibleForTesting
  Future<FlutterpiTargetPlatform> getFlutterpiTargetPlatform() async {
    try {
      final result = await sshUtils.uname(args: ['-m']);
      switch (result) {
        case 'armv7l':
          return FlutterpiTargetPlatform.genericArmV7;
        case 'aarch64':
          return FlutterpiTargetPlatform.genericAArch64;
        case 'x86_64':
          return FlutterpiTargetPlatform.genericX64;
        case 'riscv64':
          return FlutterpiTargetPlatform.genericRiscv64;
        default:
          throwToolExit(
            'SSH device "$id" has unknown target platform. `uname -m`: $result',
          );
      }
    } on SshException catch (e) {
      throwToolExit('Error querying ssh device "$id" target platform: $e');
    }
  }

  late final flutterpiTargetPlatform = getFlutterpiTargetPlatform();

  @override
  Category? get category => Category.mobile;

  @override
  void clearLogs() {}

  @override
  DeviceConnectionInterface get connectionInterface =>
      DeviceConnectionInterface.wireless;

  @override
  Future<void> dispose() async {
    await stopApp(null);
    globalLogReader.dispose();
  }

  @override
  Future<String?> get emulatorId async => null;

  @override
  bool get ephemeral => false;

  @override
  FutureOr<DeviceLogReader> getLogReader({
    ApplicationPackage? app,
    bool includePastLogs = false,
  }) {
    if (app == null) {
      return globalLogReader;
    } else {
      return logReaders.putIfAbsent(
        app.id,
        () => CustomDeviceLogReader(app.id),
      );
    }
  }

  @override
  Future<bool> installApp(
    covariant FlutterpiAppBundle app, {
    String? userIdentifier,
  }) async {
    final installDir = _getRemoteInstallPath(app);

    if (app is! PrebuiltFlutterpiAppBundle) {
      throwToolExit('Cannot install unbuilt app bundle "${app.id}".');
    }

    final status = logger.startProgress('Installing app on device...');

    try {
      await uninstallApp(app);

      try {
        await sshUtils.scp(
          localPath: app.directory.path,
          remotePath: installDir,
          throwOnError: true,
        );
      } on SshException catch (e) {
        throwToolExit('Error installing app on SSH device "$id": $e');
      }

      // make all the binaries executable on the remote device.
      final remoteBinaries = <String>[];
      for (final file in app.binaries) {
        final relative = path.relative(file.path, from: app.directory.path);
        final binaryPosix =
            path.posix.joinAll([installDir, ...path.split(relative)]);

        remoteBinaries.add(binaryPosix);
      }

      try {
        await sshUtils.makeExecutable(args: remoteBinaries);
      } on SshException catch (e) {
        throwToolExit(
          'Error making $remoteBinaries binaries executable on SSH device "$id": '
          '$e',
        );
      }
    } finally {
      status.stop();
    }

    logger.printTrace(
      'Installed app bundle "${app.directory.path}" on SSH device "$id".',
    );
    return true;
  }

  @override
  Future<bool> isAppInstalled(
    covariant FlutterpiAppBundle app, {
    String? userIdentifier,
  }) async {
    return false;
  }

  @override
  bool get isConnected => true;

  @override
  Future<bool> isLatestBuildInstalled(covariant FlutterpiAppBundle app) async {
    return false;
  }

  @override
  Future<bool> get isLocalEmulator async => false;

  @override
  bool isSupported() => true;

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    // TODO: implement isSupportedForProject
    return true;
  }

  @override
  bool get isWirelesslyConnected => true;

  @override
  final String name;

  @override
  PlatformType? get platformType => PlatformType.custom;

  @override
  DevicePortForwarder? get portForwarder => throw UnimplementedError();

  @override
  Future<MemoryInfo> queryMemoryInfo() async {
    return MemoryInfo.empty();
  }

  @override
  Future<String> get sdkNameAndVersion async => 'Linux';

  Future<FlutterpiAppBundle> _buildApp({
    required String id,
    String? mainPath,
    required DebuggingOptions debuggingOptions,
  }) async {
    /// TODO: This is partially duplicated.
    final host = switch (os.fpiHostPlatform) {
      FlutterpiHostPlatform.darwinARM64 => FlutterpiHostPlatform.darwinX64,
      FlutterpiHostPlatform.windowsARM64 => FlutterpiHostPlatform.windowsX64,
      FlutterpiHostPlatform other => other,
    };

    var target = await flutterpiTargetPlatform;
    if (!target.isGeneric &&
        debuggingOptions.buildInfo.mode == BuildMode.debug) {
      logger.printTrace(
        'Non-generic target platform ($target) is not supported for debug mode, '
        'using generic variant ${target.genericVariant}.',
      );
      target = target.genericVariant;
    }

    final artifacts = FlutterToFlutterpiArtifactsForwarder(
      inner: globals.flutterpiArtifacts,
      host: host,
      target: target,
    );

    return await buildFlutterpiApp(
      id: id,
      host: host,
      target: target,
      buildInfo: debuggingOptions.buildInfo,
      mainPath: mainPath,
      operatingSystemUtils: os,
      artifacts: artifacts,
    );
  }

  @visibleForTesting
  List<String> buildFlutterpiCommand({
    required String flutterpiExe,
    required String bundlePath,
    required BuildMode runtimeMode,
    Iterable<String> engineArgs = const [],
    Iterable<String> dartCmdlineArgs = const [],
  }) {
    final runtimeModeArg = switch (runtimeMode) {
      BuildMode.debug => null,
      BuildMode.profile => '--profile',
      BuildMode.release => '--release',
      dynamic other => throw Exception('Unsupported runtime mode: $other')
    };

    return [
      flutterpiExe,
      if (args.explicitDisplaySizeMillimeters
          case (final width, final height)) ...[
        '--dimensions',
        '$width,$height',
      ],
      if (args.useDummyDisplay) '--dummy-display',
      if (args.dummyDisplaySize case (final width, final height))
        '--dummy-display-size=$width,$height',
      if (runtimeModeArg != null) runtimeModeArg,
      bundlePath,
      ...engineArgs,
    ];
  }

  @visibleForTesting
  List<String> buildEngineArgs({
    required DebuggingOptions debuggingOptions,
    bool traceStartup = false,
    String? route,
  }) {
    final cmdlineArgs = <String>[];

    void addFlag(String value) {
      cmdlineArgs.add('--$value');
    }

    addFlag('enable-dart-profiling=true');

    if (traceStartup) {
      addFlag('trace-startup=true');
    }
    if (route != null) {
      addFlag('route=$route');
    }
    if (debuggingOptions.enableSoftwareRendering) {
      addFlag('enable-software-rendering=true');
    }
    if (debuggingOptions.skiaDeterministicRendering) {
      addFlag('skia-deterministic-rendering=true');
    }
    if (debuggingOptions.traceSkia) {
      addFlag('trace-skia=true');
    }
    if (debuggingOptions.traceAllowlist != null) {
      addFlag('trace-allowlist=${debuggingOptions.traceAllowlist}');
    }
    if (debuggingOptions.traceSkiaAllowlist != null) {
      addFlag('trace-skia-allowlist=${debuggingOptions.traceSkiaAllowlist}');
    }
    if (debuggingOptions.traceSystrace) {
      addFlag('trace-systrace=true');
    }
    if (debuggingOptions.traceToFile != null) {
      addFlag('trace-to-file=${debuggingOptions.traceToFile}');
    }
    if (debuggingOptions.endlessTraceBuffer) {
      addFlag('endless-trace-buffer=true');
    }
    if (debuggingOptions.purgePersistentCache) {
      addFlag('purge-persistent-cache=true');
    }

    switch (debuggingOptions.enableImpeller) {
      case ImpellerStatus.enabled:
        addFlag('enable-impeller=true');
      case ImpellerStatus.disabled:
        addFlag('enable-impeller=false');
      case ImpellerStatus.platformDefault:
    }

    // Options only supported when there is a VM Service connection between the
    // tool and the device, usually in debug or profile mode.
    if (debuggingOptions.debuggingEnabled) {
      if (debuggingOptions.deviceVmServicePort != null) {
        addFlag('vm-service-port=${debuggingOptions.deviceVmServicePort}');
      }
      if (debuggingOptions.buildInfo.isDebug) {
        addFlag('enable-checked-mode=true');
        addFlag('verify-entry-points=true');
      }
      if (debuggingOptions.startPaused) {
        addFlag('start-paused=true');
      }
      if (debuggingOptions.disableServiceAuthCodes) {
        addFlag('disable-service-auth-codes=true');
      }
      final String dartVmFlags = debuggingOptions.dartFlags;
      if (dartVmFlags.isNotEmpty) {
        addFlag('dart-flags=$dartVmFlags');
      }
      if (debuggingOptions.useTestFonts) {
        addFlag('use-test-fonts=true');
      }
      if (debuggingOptions.verboseSystemLogs) {
        addFlag('verbose-logging=true');
      }
    }

    return cmdlineArgs;
  }

  @override
  Future<LaunchResult> startApp(
    covariant FlutterpiAppBundle? package, {
    String? mainPath,
    String? route,
    required DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs = const {},
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String? userIdentifier,
  }) async {
    final prebuiltApp = switch (package) {
      PrebuiltFlutterpiAppBundle prebuilt => prebuilt,
      BuildableFlutterpiAppBundle buildable => await _buildApp(
          id: buildable.id,
          mainPath: mainPath,
          debuggingOptions: debuggingOptions,
        ),
      dynamic _ => throwToolExit(
          'Cannot start app on SSH device "$id" without an app bundle.',
        ),
    };

    await installApp(prebuiltApp, userIdentifier: userIdentifier);

    final remoteInstallPath = _getRemoteInstallPath(prebuiltApp);
    final flutterpiExePath = path.posix.join(remoteInstallPath, 'flutter-pi');

    final hostPort = switch (debuggingOptions.hostVmServicePort) {
      int port => port,
      null => await os.findFreePort(),
    };

    final devicePort = switch (debuggingOptions.deviceVmServicePort) {
      int port => port,
      null => hostPort,
    };

    final List<String> command;
    try {
      final engineArgs = buildEngineArgs(
        debuggingOptions: debuggingOptions,
        traceStartup: false,
        route: route,
      );

      command = buildFlutterpiCommand(
        flutterpiExe: flutterpiExePath,
        bundlePath: remoteInstallPath,
        runtimeMode: debuggingOptions.buildInfo.mode,
        engineArgs: [
          ...engineArgs,
          if (debuggingOptions.deviceVmServicePort == null)
            '--vm-service-port=$devicePort',
        ],
      );
    } on Exception catch (e) {
      throwToolExit(e.toString());
    }

    final sshProcess = await sshUtils.startSsh(
      command: command.join(' '),
      allocateTTY: true,
      localPortForwards: [
        (hostPort, devicePort),
      ],
      exitOnForwardFailure: true,
    );

    final logReader = logReaders.putIfAbsent(
      prebuiltApp.id,
      () => CustomDeviceLogReader(prebuiltApp.name),
    );
    globalLogReader.listenToLinesStream(logReader.logLines);
    logReader.listenToProcessOutput(sshProcess);

    final runningApp = _RunningApp(
      app: prebuiltApp,
      sshProcess: sshProcess,
      logReader: logReader,
      sshUtils: sshUtils,
      os: os,
    );

    final discovery = ProtocolDiscovery.vmService(
      logReader,
      portForwarder: NoOpDevicePortForwarder(),
      logger: logger,
      hostPort: hostPort,
      devicePort: devicePort,
      ipv6: ipv6,
    );

    final uriCompleter = Completer<Uri>();

    sshProcess.exitCode.then((exitCode) {
      if (!uriCompleter.isCompleted) {
        if (exitCode != 0) {
          const kUnsatisfiedLinkDependencies = 127;
          if (exitCode == kUnsatisfiedLinkDependencies) {
            final installDepsSshCommand = sshUtils
                .buildSshCommand(
                  command:
                      '\'sudo sh -c "apt-get update && apt-get install -y libdrm2 libgbm1 libsystemd0 libinput10 libxkbcommon0 libudev1 libegl1 libgles2 libvulkan1 libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libglib2.0-0"\'',
                )
                .join(' ');

            uriCompleter.completeError(
              Exception(
                  'Make sure all required runtime dependencies are installed on the device.\n'
                  'For example, for targets runned debian-based distros, you can execute:\n'
                  '  $installDepsSshCommand'),
            );
          } else {
            uriCompleter.completeError(
              ProcessException(
                flutterpiExePath,
                command.skip(1).toList(),
                'Process exited abnormally with code $exitCode',
                exitCode,
              ),
            );
          }
        } else {
          uriCompleter.completeError(
            Exception('Process exited without providing a VM service URI.'),
          );
        }
      }
    });

    discovery.uri.then(uriCompleter.complete);

    try {
      final uri = await uriCompleter.future;

      runningApps[prebuiltApp.id] = runningApp;
      return LaunchResult.succeeded(vmServiceUri: uri);
    } on Exception catch (e) {
      logger.printError(e.toString(), wrap: false);
    }

    return LaunchResult.failed();
  }

  @override
  Future<bool> stopApp(
    covariant FlutterpiAppBundle? app, {
    String? userIdentifier,
  }) async {
    if (app == null) {
      logger.printTrace('Stopping all apps on SSH device "$id": $runningApps');

      final apps = List.of(runningApps.values);
      runningApps.clear();

      final results = await Future.wait(
        apps.map((app) async {
          logger.printTrace('Stopping app "${app.app.id}" on SSH device "$id"');
          return await app.stop();
        }),
      );
      return results.any((result) => !result);
    } else {
      logger
          .printTrace('Attempting to stop app "${app.id}" on SSH device "$id"');

      final runningApp = runningApps.remove(app.id);
      if (runningApp == null) {
        logger.printTrace(
          'Attempted to kill non-running app "${app.id}" on SSH device "$id".',
        );
        return false;
      }

      return await runningApp.stop();
    }
  }

  @override
  bool get supportsFastStart => false;

  @override
  bool get supportsFlavors => false;

  @override
  bool get supportsFlutterExit => false;

  @override
  Future<bool> get supportsHardwareRendering async => true;

  @override
  bool get supportsHotReload => true;

  @override
  bool get supportsHotRestart => true;

  @override
  FutureOr<bool> supportsRuntimeMode(BuildMode buildMode) {
    return buildMode != BuildMode.jitRelease;
  }

  @override
  bool get supportsScreenshot => false;

  @override
  bool get supportsStartPaused => false;

  @override
  Future<void> takeScreenshot(File outputFile) {
    throw UnimplementedError();
  }

  @override
  Future<TargetPlatform> get targetPlatform async =>
      switch (await flutterpiTargetPlatform) {
        FlutterpiTargetPlatform.genericArmV7 ||
        FlutterpiTargetPlatform.pi3 ||
        FlutterpiTargetPlatform.pi4 =>
          TargetPlatform.linux_arm64,
        FlutterpiTargetPlatform.genericRiscv64 => TargetPlatform.linux_arm64,
        FlutterpiTargetPlatform.genericAArch64 ||
        FlutterpiTargetPlatform.pi3_64 ||
        FlutterpiTargetPlatform.pi4_64 =>
          TargetPlatform.linux_arm64,
        FlutterpiTargetPlatform.genericX64 => TargetPlatform.linux_x64,
      };

  @override
  Future<bool> uninstallApp(
    covariant FlutterpiAppBundle app, {
    String? userIdentifier,
  }) async {
    final path = _getRemoteInstallPath(app);

    try {
      await sshUtils.runSsh(command: 'rm -rf "$path"', throwOnError: true);
    } on SshException catch (e) {
      logger.printError('Error uninstalling app on SSH device "$id": $e');
      return false;
    }

    logger.printTrace(
      'Uninstalled app bundle "${app.id}" from SSH device "$id".',
    );
    return true;
  }
}
