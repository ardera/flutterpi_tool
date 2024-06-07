import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/commands/build_bundle.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
// import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:path/path.dart' as path;

class SshException implements Exception {
  SshException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SshUtils {
  SshUtils({
    required this.processUtils,
    this.sshExecutable = 'ssh',
    this.scpExecutable = 'scp',
    required this.defaultRemote,
  });

  final String sshExecutable;
  final String scpExecutable;
  final String defaultRemote;
  final ProcessUtils processUtils;

  static const defaultArgs = ['-o', 'BatchMode=yes'];

  List<String> buildSshCommand({
    Iterable<String> baseArgs = defaultArgs,
    bool? allocateTTY,
    bool? exitOnForwardFailure,
    Iterable<int> remotePortForwards = const [],
    Iterable<int> localPortForwards = const [],
    String? remote,
    String? command,
  }) {
    remote ??= defaultRemote;

    return <String>[
      sshExecutable,
      ...baseArgs,
      if (allocateTTY == true) '-tt',
      if (exitOnForwardFailure == true) ...[
        '-o',
        'ExitOnForwardFailure=yes'
      ] else if (exitOnForwardFailure == false) ...[
        '-o',
        'ExitOnForwardFailure=no'
      ],
      for (final port in localPortForwards) ...[
        '-L',
        '$port:localhost:$port',
      ],
      for (final port in remotePortForwards) ...[
        '-R',
        '$port:localhost:$port',
      ],
      if (command == null) '-T',
      remote,
      if (command != null) command,
    ];
  }

  Future<RunResult> runSsh({
    String? remote,
    String? command,
    Iterable<String> baseArgs = defaultArgs,
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
    bool? allocateTTY,
    Iterable<int> localPortForwards = const [],
    bool? exitOnForwardFailure,
  }) {
    remote ??= defaultRemote;

    final cmd = buildSshCommand(
      baseArgs: baseArgs,
      allocateTTY: allocateTTY,
      exitOnForwardFailure: exitOnForwardFailure,
      localPortForwards: localPortForwards,
      remote: remote,
      command: command,
    );

    try {
      return processUtils.run(
        cmd,
        throwOnError: throwOnError,
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: timeout,
        timeoutRetries: timeoutRetries,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 255:
          throw SshException('SSH to "$remote" failed: $e');
        default:
          throw SshException('Remote command failed: $e');
      }
    }
  }

  Future<Process> startSsh({
    String? remote,
    String? command,
    Iterable<String> baseArgs = defaultArgs,
    String? workingDirectory,
    Map<String, String>? environment,
    bool? allocateTTY,
    Iterable<int> remotePortForwards = const [],
    Iterable<int> localPortForwards = const [],
    bool? exitOnForwardFailure,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    remote ??= defaultRemote;

    final cmd = buildSshCommand(
      baseArgs: baseArgs,
      allocateTTY: allocateTTY,
      exitOnForwardFailure: exitOnForwardFailure,
      localPortForwards: localPortForwards,
      remote: remote,
      command: command,
    );

    try {
      return processUtils.start(
        cmd,
        workingDirectory: workingDirectory,
        environment: environment,
        mode: mode,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 255:
          throw SshException('SSH to "$remote" failed: $e');
        default:
          throw SshException('Remote command failed: $e');
      }
    }
  }

  Future<RunResult> scp({
    String? remote,
    required String localPath,
    required String remotePath,
    Iterable<String> baseArgs = defaultArgs,
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
    bool recursive = true,
  }) {
    remote ??= defaultRemote;

    try {
      return processUtils.run(
        [
          scpExecutable,
          ...baseArgs,
          if (recursive) '-r',
          localPath,
          '$remote:$remotePath',
        ],
        throwOnError: throwOnError,
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: timeout,
        timeoutRetries: timeoutRetries,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 255:
          throw SshException('SSH to remote "$remote" failed: $e');
        default:
          throw SshException('Remote command failed: $e');
      }
    }
  }

  Future<bool> tryConnect({
    Duration? timeout,
    bool throwOnError = false,
  }) async {
    final timeoutSecondsCeiled = switch (timeout) {
      Duration(inMicroseconds: final micros) =>
        (micros + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond,
      _ => null,
    };

    final result = await runSsh(
      command: null,
      baseArgs: [
        ...defaultArgs,
        '-T',
        if (timeoutSecondsCeiled != null) ...[
          '-o',
          'ConnectTimeout=$timeoutSecondsCeiled',
        ],
      ],
      throwOnError: throwOnError,
    );

    if (result.exitCode == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> copy({
    required String localPath,
    required String remotePath,
    String? remote,
  }) {
    return scp(
      baseArgs: [
        ...defaultArgs,
        '-r',
      ],
      localPath: localPath,
      remotePath: remotePath,
      remote: remote,
      throwOnError: true,
    );
  }

  Future<String> uname({Iterable<String>? args, Duration? timeout}) async {
    final command = ['uname', ...?args].join(' ');

    final result = await runSsh(
      command: command,
      throwOnError: true,
      timeout: timeout,
    );

    return result.stdout.trim();
  }
}

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

class ProcessDeviceLogReader extends DeviceLogReader {
  ProcessDeviceLogReader(this.name);

  /// The name of the device this log reader is associated with.
  @override
  final String name;

  final _controller = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<String>>[];

  /// Listen to [process]' stdout and stderr, decode them using [SystemEncoding]
  /// and add each decoded line to [logLines].
  ///
  /// However, [logLines] will not be done when the [process]' stdout and stderr
  /// streams are done. So [logLines] will still be alive after the process has
  /// finished.
  ///
  /// See [CustomDeviceLogReader.dispose] to end the [logLines] stream.
  void listenToProcessOutput(
    Process process, {
    Encoding encoding = systemEncoding,
    bool Function(int)? allowedExitCodes,
    String? executable,
    List<String>? arguments,
  }) {
    allowedExitCodes ??= (exitCode) => exitCode == 0;

    final decodeLines = StreamTransformer<List<int>, String>.fromBind((out) {
      return out.transform(encoding.decoder).transform(const LineSplitter());
    });

    _subscriptions.add(
      process.stdout.transform(decodeLines).listen(_controller.add),
    );

    _subscriptions.add(
      process.stderr.transform(decodeLines).listen(_controller.add),
    );

    process.exitCode.then((exitCode) {
      allowedExitCodes!;

      if (!allowedExitCodes(exitCode)) {
        _controller.addError(ProcessException(
          executable ?? '',
          arguments ?? const [],
          'Process exited with exit code $exitCode',
          exitCode,
        ));
      }
    });
  }

  /// Add all lines emitted by [lines] to this [CustomDeviceLogReader]s [logLines]
  /// stream.
  ///
  /// Similar to [listenToProcessOutput], [logLines] will not be marked as done
  /// when the argument stream is done.
  ///
  /// Useful when you want to combine the contents of multiple log readers.
  void listenToLinesStream(Stream<String> lines) {
    _subscriptions.add(lines.listen(_controller.add));
  }

  /// Dispose this log reader, freeing all associated resources and marking
  /// [logLines] as done.
  @override
  Future<void> dispose() async {
    final List<Future<void>> futures = <Future<void>>[];

    for (final StreamSubscription<String> subscription in _subscriptions) {
      futures.add(subscription.cancel());
    }

    futures.add(_controller.close());

    await Future.wait(futures);
  }

  @override
  Stream<String> get logLines => _controller.stream;
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
  final globalLogReader = ProcessDeviceLogReader('FlutterPi');

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
    return ProcessDeviceLogReader(app?.name ?? name);
  }

  @override
  Future<bool> installApp(covariant FlutterpiAppBundle app, {String? userIdentifier}) async {
    final installDir = _getRemoteInstallPath(app);

    if (app is! PrebuiltFlutterpiAppBundle) {
      throwToolExit('Cannot install unbuilt app bundle "${app.id}".');
    }

    await uninstallApp(app);

    try {
      await sshUtils.scp(localPath: app.directory.path, remotePath: installDir, throwOnError: true);
    } on SshException catch (e) {
      throwToolExit('Error installing app on SSH device "$id": $e');
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

    final runtimeModeArg = switch (debuggingOptions.buildInfo.mode) {
      BuildMode.debug => null,
      BuildMode.profile => '--profile',
      BuildMode.release => '--release',
      dynamic other => throwToolExit('Unsupported runtime mode: $other')
    };

    final port = await os.findFreePort();

    final command = [
      flutterpiExePath,
      if (runtimeModeArg != null) runtimeModeArg,
      remoteInstallPath,
      '--vm-service-port=$port'
    ];

    final sshProcess = await sshUtils.startSsh(
      command: command.join(' '),
      allocateTTY: true,
      localPortForwards: [port],
      exitOnForwardFailure: true,
    );

    final logReader = CustomDeviceLogReader(prebuiltApp.name);
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
          uriCompleter.completeError(ProcessException(
            flutterpiExePath,
            command.skip(1).toList(),
            'Process exited abnormally with code $exitCode',
            exitCode,
          ));
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
      logger.printError(e.toString());
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
