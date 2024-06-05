import 'dart:async';
import 'dart:io';

import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:meta/meta.dart';

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
    required this.defaultRemote,
  });

  final String sshExecutable;
  final String defaultRemote;
  final ProcessUtils processUtils;

  @protected
  List<String> getDefaultArgs() {
    return ['-o', 'BatchMode=yes'];
  }

  Future<RunResult> runSsh({
    required String? remoteCommand,
    String? remote,
    Iterable<String>? sshArgs,
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
  }) {
    sshArgs ??= getDefaultArgs();
    remote ??= defaultRemote;

    try {
      return processUtils.run(
        <String>[
          sshExecutable,
          ...sshArgs,
          remote,
          if (remoteCommand != null) remoteCommand,
        ],
        throwOnError: throwOnError,
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: timeout,
        timeoutRetries: timeoutRetries,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 2:
        case 74:
          throw SshException('Connection to host failed.');
        case 78:
          throw SshException('Authentication failed.');
        default:
          throw SshException('Failed to run ssh: $e');
      }
    }
  }

  Future<RunResult> runScp({
    String? remote,
    required String localPath,
    required String remotePath,
    Iterable<String>? sshArgs,
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
  }) {
    sshArgs ??= getDefaultArgs();
    remote ??= defaultRemote;

    try {
      return processUtils.run(
        [
          sshExecutable,
          ...sshArgs,
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
        case 2:
        case 74:
          throw SshException('Connection to host failed.');
        case 78:
          throw SshException('Authentication failed.');
        default:
          throw SshException('Failed to run ssh: $e');
      }
    }
  }

  Future<RunResult> runRemoteCommand(
    String command, {
    String? remote,
    Iterable<String>? sshArgs,
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
  }) {
    return runSsh(
      remoteCommand: command,
      throwOnError: throwOnError,
      workingDirectory: workingDirectory,
      environment: environment,
      timeout: timeout,
      timeoutRetries: timeoutRetries,
    );
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
      remoteCommand: null,
      sshArgs: [
        ...getDefaultArgs(),
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
    return runScp(
      sshArgs: [
        ...getDefaultArgs(),
        '-r',
      ],
      localPath: localPath,
      remotePath: remotePath,
      remote: remote,
      throwOnError: true,
    );
  }
}

class SshDevice extends Device {
  SshDevice({
    required String id,
    required this.sshUtils,
  }) : super(
          id,
          category: Category.mobile,
          platformType: PlatformType.custom,
          ephemeral: false,
        );

  final SshUtils sshUtils;

  @override
  Category? get category => Category.mobile;

  @override
  void clearLogs() {}

  @override
  DeviceConnectionInterface get connectionInterface => DeviceConnectionInterface.wireless;

  @override
  Future<void> dispose() {
    // TODO: implement dispose
    throw UnimplementedError();
  }

  @override
  Future<String?> get emulatorId async => null;

  @override
  bool get ephemeral => false;

  @override
  FutureOr<DeviceLogReader> getLogReader({ApplicationPackage? app, bool includePastLogs = false}) {
    // TODO: implement getLogReader
    throw UnimplementedError();
  }

  @override
  String get id => 'ssh';

  @override
  Future<bool> installApp(ApplicationPackage app, {String? userIdentifier}) {
    // TODO: implement
    throw UnimplementedError();
  }

  @override
  Future<bool> isAppInstalled(ApplicationPackage app, {String? userIdentifier}) {
    // TODO: implement isAppInstalled
    throw UnimplementedError();
  }

  @override
  bool get isConnected => throw UnimplementedError();

  @override
  Future<bool> isLatestBuildInstalled(ApplicationPackage app) {
    // TODO: implement isLatestBuildInstalled
    throw UnimplementedError();
  }

  @override
  // TODO: implement isLocalEmulator
  Future<bool> get isLocalEmulator => throw UnimplementedError();

  @override
  bool isSupported() {
    // TODO: implement isSupported
    throw UnimplementedError();
  }

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    // TODO: implement isSupportedForProject
    throw UnimplementedError();
  }

  @override
  bool get isWirelesslyConnected => true;

  @override
  String get name => 'ssh-name';

  @override
  PlatformType? get platformType => PlatformType.custom;

  @override
  DevicePortForwarder? get portForwarder => throw UnimplementedError();

  @override
  Future<MemoryInfo> queryMemoryInfo() {
    // TODO: implement queryMemoryInfo
    throw UnimplementedError();
  }

  @override
  Future<String> get sdkNameAndVersion => throw UnimplementedError();

  @override
  Future<LaunchResult> startApp(
    covariant ApplicationPackage? package, {
    String? mainPath,
    String? route,
    required DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs,
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String? userIdentifier,
  }) {
    // TODO: implement startApp
    throw UnimplementedError();
  }

  @override
  Future<bool> stopApp(ApplicationPackage? app, {String? userIdentifier}) {
    // TODO: implement stopApp
    throw UnimplementedError();
  }

  @override
  String supportMessage() {
    // TODO: implement supportMessage
    throw UnimplementedError();
  }

  @override
  bool get supportsFastStart => throw UnimplementedError();

  @override
  bool get supportsFlavors => throw UnimplementedError();

  @override
  bool get supportsFlutterExit => throw UnimplementedError();

  @override
  Future<bool> get supportsHardwareRendering => throw UnimplementedError();

  @override
  bool get supportsHotReload => throw UnimplementedError();

  @override
  bool get supportsHotRestart => throw UnimplementedError();

  @override
  FutureOr<bool> supportsRuntimeMode(BuildMode buildMode) {
    // TODO: implement supportsRuntimeMode
    throw UnimplementedError();
  }

  @override
  bool get supportsScreenshot => throw UnimplementedError();

  @override
  bool get supportsStartPaused => throw UnimplementedError();

  @override
  Future<void> takeScreenshot(File outputFile) {
    // TODO: implement takeScreenshot
    throw UnimplementedError();
  }

  @override
  Future<TargetPlatform> get targetPlatform async => TargetPlatform.linux_arm64;

  @override
  Future<bool> uninstallApp(ApplicationPackage app, {String? userIdentifier}) {
    // TODO: implement uninstallApp
    throw UnimplementedError();
  }
}
