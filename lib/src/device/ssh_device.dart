import 'dart:async';
import 'dart:io';

import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/commands/build_bundle.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/device/ssh_utils.dart';
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
  }) : super(id: id, name: name, displayName: displayName);

  final Directory directory;
}

class RunningApp {
  RunningApp({
    required this.app,
    required this.sshProcess,
    required this.logReader,
  });

  final FlutterpiAppBundle app;
  final Process sshProcess;
  final DeviceLogReader logReader;

  Future<bool> stop({Duration timeout = const Duration(seconds: 5)}) async {
    logReader.dispose();

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
}

class SshDevice extends Device {
  SshDevice({
    required String id,
    required this.name,
    required this.sshUtils,
    required String? remoteInstallPath,
    required this.logger,
    required this.os,
    required this.cache,
    this.explicitDevicePixelRatio,
    this.explicitDisplaySizeMillimeters,
  })  : remoteInstallPath = remoteInstallPath ?? '/tmp/',
        super(
          id,
          category: Category.mobile,
          platformType: PlatformType.custom,
          ephemeral: false,
        );

  final SshUtils sshUtils;
  final String remoteInstallPath;
  final Logger logger;
  final FlutterpiCache cache;
  final MoreOperatingSystemUtils os;

  final runningApps = <String, RunningApp>{};
  final logReaders = <String, CustomDeviceLogReader>{};
  final globalLogReader = CustomDeviceLogReader('FlutterPi');

  final double? explicitDevicePixelRatio;
  final (int, int)? explicitDisplaySizeMillimeters;

  String _getRemoteInstallPath(FlutterpiAppBundle bundle) {
    return path.posix.join(remoteInstallPath, bundle.id);
  }

  Future<FlutterpiTargetPlatform> _getFlutterpiTargetPlatform() async {
    try {
      final result = await sshUtils.uname(args: ['-m']);
      switch (result) {
        case 'armv7l':
          return FlutterpiTargetPlatform.genericArmV7;
        case 'aarch64':
          return FlutterpiTargetPlatform.genericAArch64;
        case 'x86_64':
          return FlutterpiTargetPlatform.genericX64;
        default:
          throwToolExit('SSH device "$id" has unknown target platform. `uname -m`: $result');
      }
    } on SshException catch (e) {
      throwToolExit('Error querying ssh device "$id" target platform: $e');
    }
  }

  @override
  Category? get category => Category.mobile;

  @override
  void clearLogs() {}

  @override
  DeviceConnectionInterface get connectionInterface => DeviceConnectionInterface.wireless;

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
  FutureOr<DeviceLogReader> getLogReader({ApplicationPackage? app, bool includePastLogs = false}) {
    if (app == null) {
      return globalLogReader;
    } else {
      return logReaders.putIfAbsent(app.id, () => CustomDeviceLogReader(app.id));
    }
  }

  @override
  Future<bool> installApp(covariant FlutterpiAppBundle app, {String? userIdentifier}) async {
    final installDir = _getRemoteInstallPath(app);

    if (app is! PrebuiltFlutterpiAppBundle) {
      throwToolExit('Cannot install unbuilt app bundle "${app.id}".');
    }

    final status = logger.startProgress('Installing app on device...');

    try {
      await uninstallApp(app);

      try {
        await sshUtils.scp(localPath: app.directory.path, remotePath: installDir, throwOnError: true);
      } on SshException catch (e) {
        throwToolExit('Error installing app on SSH device "$id": $e');
      }
    } finally {
      status.stop();
    }

    logger.printTrace('Installed app bundle "${app.directory.path}" on SSH device "$id".');
    return true;
  }

  @override
  Future<bool> isAppInstalled(covariant FlutterpiAppBundle app, {String? userIdentifier}) async {
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
    return await buildFlutterpiApp(
      id: id,
      host: os.fpiHostPlatform,
      target: await _getFlutterpiTargetPlatform(),
      buildInfo: debuggingOptions.buildInfo,
      artifactPaths: cache.artifactPaths,
      mainPath: mainPath,
    );
  }

  @visibleForTesting
  List<String> buildFlutterpiCommand({
    required String flutterpiExe,
    required String bundlePath,
    required DebuggingOptions debuggingOptions,
    Iterable<String> engineArgs = const [],
  }) {
    final runtimeModeArg = switch (debuggingOptions.buildInfo.mode) {
      BuildMode.debug => null,
      BuildMode.profile => '--profile',
      BuildMode.release => '--release',
      dynamic other => throw Exception('Unsupported runtime mode: $other')
    };

    return [
      flutterpiExe,
      if (explicitDisplaySizeMillimeters case (final width, final height)) ...[
        '--dimensions',
        '$width,$height',
      ],
      if (runtimeModeArg != null) runtimeModeArg,
      bundlePath,
      ...engineArgs,
    ];
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
      dynamic _ => throwToolExit('Cannot start app on SSH device "$id" without an app bundle.'),
    };

    await installApp(prebuiltApp, userIdentifier: userIdentifier);

    final remoteInstallPath = _getRemoteInstallPath(prebuiltApp);
    final flutterpiExePath = path.posix.join(remoteInstallPath, 'flutter-pi');

    final port = await os.findFreePort();

    final List<String> command;
    try {
      command = buildFlutterpiCommand(
        flutterpiExe: flutterpiExePath,
        bundlePath: remoteInstallPath,
        debuggingOptions: debuggingOptions,
        engineArgs: ['--vm-service-port=$port'],
      );
    } on Exception catch (e) {
      throwToolExit(e.toString());
    }

    final sshProcess = await sshUtils.startSsh(
      command: command.join(' '),
      allocateTTY: true,
      localPortForwards: [port],
      exitOnForwardFailure: true,
    );

    final logReader = logReaders.putIfAbsent(prebuiltApp.id, () => CustomDeviceLogReader(prebuiltApp.name));
    globalLogReader.listenToLinesStream(logReader.logLines);
    logReader.listenToProcessOutput(sshProcess);

    final runningApp = RunningApp(
      app: prebuiltApp,
      sshProcess: sshProcess,
      logReader: logReader,
    );

    final discovery = ProtocolDiscovery.vmService(
      logReader,
      portForwarder: NoOpDevicePortForwarder(),
      logger: logger,
      hostPort: port,
      devicePort: port,
      ipv6: false,
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
              Exception('Make sure all required runtime dependencies are installed on the device.\n'
                  'For example, for targets runned debian-based distros, you can execute:\n'
                  '  $installDepsSshCommand'),
            );
          } else {
            uriCompleter.completeError(ProcessException(
              flutterpiExePath,
              command.skip(1).toList(),
              'Process exited abnormally with code $exitCode',
              exitCode,
            ));
          }
        } else {
          uriCompleter.completeError(Exception('Process exited without providing a VM service URI.'));
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
  Future<bool> stopApp(covariant FlutterpiAppBundle? app, {String? userIdentifier}) async {
    if (app == null) {
      final apps = runningApps.values.toList();
      runningApps.clear();

      final results = await Future.wait(apps.map((app) => app.stop()));
      return results.any((result) => !result);
    } else {
      final runningApp = runningApps.remove(app.id);
      if (runningApp == null) {
        logger.printTrace('Attempted to kill non-running app "${app.id}" on SSH device "$id".');
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
  Future<TargetPlatform> get targetPlatform async => TargetPlatform.linux_arm64;

  @override
  Future<bool> uninstallApp(covariant FlutterpiAppBundle app, {String? userIdentifier}) async {
    final path = _getRemoteInstallPath(app);

    try {
      await sshUtils.runSsh(command: 'rm -rf "$path"', throwOnError: true);
    } on SshException catch (e) {
      logger.printError('Error uninstalling app on SSH device "$id": $e');
      return false;
    }

    logger.printTrace('Uninstalled app bundle "${app.id}" from SSH device "$id".');
    return true;
  }
}
