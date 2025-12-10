import 'dart:async';

import 'package:flutter_tools/src/base/dds.dart';
import 'package:flutter_tools/src/device_vm_service_discovery_for_attach.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:test/test.dart';

class FakeDevice implements fl.Device {
  fl.DevFSWriter? Function(fl.ApplicationPackage? app, String? userIdentifier)?
      createDevFSWriterFn;
  Future<void> Function()? disposeFn;
  Future<String?> Function()? emulatorIdFn;
  FutureOr<fl.DeviceLogReader> Function({
    fl.ApplicationPackage? app,
    bool includePastLogs,
  })? getLogReaderFn;
  VMServiceDiscoveryForAttach Function({
    String? appId,
    String? fuchsiaModule,
    int? filterDevicePort,
    int? expectedHostPort,
    required bool ipv6,
    required fl.Logger logger,
  })? getVMServiceDiscoveryForAttachFn;
  Future<bool> Function(fl.ApplicationPackage app, {String? userIdentifier})?
      installAppFn;
  Future<bool> Function(fl.ApplicationPackage app, {String? userIdentifier})?
      isAppInstalledFn;
  Future<bool> Function(fl.ApplicationPackage app)? isLatestBuildInstalledFn;
  Future<bool> Function()? isSupportedFn;
  bool Function(fl.FlutterProject flutterProject)? isSupportedForProjectFn;
  Future<fl.MemoryInfo> Function()? queryMemoryInfoFn;
  Future<fl.LaunchResult> Function(
    fl.ApplicationPackage? package, {
    String? mainPath,
    String? route,
    required fl.DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs,
    bool prebuiltApplication,
    String? userIdentifier,
  })? startAppFn;
  Future<bool> Function(fl.ApplicationPackage? app, {String? userIdentifier})?
      stopAppFn;
  Future<String> Function()? supportMessageFn;
  FutureOr<bool> Function(fl.BuildMode buildMode)? supportsRuntimeModeFn;
  Future<void> Function(fl.File outputFile)? takeScreenshotFn;
  Future<Map<String, Object>> Function()? toJsonFn;
  Future<bool> Function(fl.ApplicationPackage app, {String? userIdentifier})?
      uninstallAppFn;

  FakeDevice({
    this.id = 'test-device',
    this.name = 'Test Device',
    this.displayName = 'Test Device',
    String? sdkNameAndVersion,
    fl.TargetPlatform? targetPlatform,
    String? targetPlatformDisplayName,
    this.category = fl.Category.mobile,
    this.platformType = fl.PlatformType.android,
    this.connectionInterface = fl.DeviceConnectionInterface.attached,
  })  : sdkNameAndVersion = Future.value(sdkNameAndVersion ?? 'Fake SDK 1.0.0'),
        targetPlatform =
            Future.value(targetPlatform ?? fl.TargetPlatform.android_arm64),
        targetPlatformDisplayName =
            Future.value(targetPlatformDisplayName ?? 'Android (arm64)'),
        isSupportedFn = (() => Future.value(true));

  @override
  fl.Category? category;

  @override
  fl.DeviceConnectionInterface connectionInterface;

  DartDevelopmentService? _dds;

  set dds(DartDevelopmentService value) => _dds = value;

  @override
  DartDevelopmentService get dds {
    if (_dds == null) fail('Should not access dds');
    return _dds!;
  }

  @override
  String displayName;

  @override
  bool ephemeral = false;

  @override
  String id;

  @override
  bool isConnected = true;

  bool localEmulator = false;

  @override
  Future<bool> get isLocalEmulator => Future.value(localEmulator);

  @override
  bool get isWirelesslyConnected {
    return connectionInterface == fl.DeviceConnectionInterface.wireless;
  }

  @override
  String name;

  @override
  fl.PlatformType platformType;

  @override
  fl.DevicePortForwarder? portForwarder;

  @override
  Future<String> sdkNameAndVersion;

  @override
  bool supportsFlavors = true;

  @override
  bool supportsFlutterExit = true;

  @override
  Future<bool> supportsHardwareRendering = Future.value(true);

  @override
  bool supportsHotReload = true;

  @override
  bool supportsHotRestart = true;

  @override
  bool supportsScreenshot = true;

  @override
  bool supportsStartPaused = true;

  @override
  Future<fl.TargetPlatform> targetPlatform;

  @override
  Future<String> targetPlatformDisplayName;

  // Methods and function fields
  @override
  void clearLogs() {}

  @override
  fl.DevFSWriter? createDevFSWriter(
    fl.ApplicationPackage? app,
    String? userIdentifier,
  ) {
    if (createDevFSWriterFn != null) {
      return createDevFSWriterFn!(app, userIdentifier);
    }
    fail('Should not access createDevFSWriter');
  }

  @override
  Future<void> dispose() {
    if (disposeFn != null) return disposeFn!();
    fail('Should not access dispose');
  }

  @override
  Future<String?> get emulatorId {
    if (emulatorIdFn != null) return emulatorIdFn!();
    fail('Should not access emulatorId');
  }

  @override
  FutureOr<fl.DeviceLogReader> getLogReader({
    fl.ApplicationPackage? app,
    bool includePastLogs = false,
  }) {
    if (getLogReaderFn != null) {
      return getLogReaderFn!(app: app, includePastLogs: includePastLogs);
    }
    fail('Should not access getLogReader');
  }

  @override
  VMServiceDiscoveryForAttach getVMServiceDiscoveryForAttach({
    String? appId,
    String? fuchsiaModule,
    int? filterDevicePort,
    int? expectedHostPort,
    required bool ipv6,
    required fl.Logger logger,
  }) {
    if (getVMServiceDiscoveryForAttachFn != null) {
      return getVMServiceDiscoveryForAttachFn!(
        appId: appId,
        fuchsiaModule: fuchsiaModule,
        filterDevicePort: filterDevicePort,
        expectedHostPort: expectedHostPort,
        ipv6: ipv6,
        logger: logger,
      );
    }
    fail('Should not access getVMServiceDiscoveryForAttach');
  }

  @override
  Future<bool> installApp(fl.ApplicationPackage app, {String? userIdentifier}) {
    if (installAppFn != null) {
      return installAppFn!(app, userIdentifier: userIdentifier);
    }
    fail('Should not access installApp');
  }

  @override
  Future<bool> isAppInstalled(
    fl.ApplicationPackage app, {
    String? userIdentifier,
  }) {
    if (isAppInstalledFn != null) {
      return isAppInstalledFn!(app, userIdentifier: userIdentifier);
    }
    fail('Should not access isAppInstalled');
  }

  @override
  Future<bool> isLatestBuildInstalled(fl.ApplicationPackage app) {
    if (isLatestBuildInstalledFn != null) return isLatestBuildInstalledFn!(app);
    fail('Should not access isLatestBuildInstalled');
  }

  @override
  Future<bool> isSupported() async {
    if (isSupportedFn != null) return isSupportedFn!();
    fail('Should not access isSupported');
  }

  @override
  bool isSupportedForProject(fl.FlutterProject flutterProject) {
    if (isSupportedForProjectFn != null) {
      return isSupportedForProjectFn!(flutterProject);
    }
    fail('Should not access isSupportedForProject');
  }

  @override
  Future<fl.MemoryInfo> queryMemoryInfo() {
    if (queryMemoryInfoFn != null) return queryMemoryInfoFn!();
    fail('Should not access queryMemoryInfo');
  }

  @override
  Future<fl.LaunchResult> startApp(
    covariant fl.ApplicationPackage? package, {
    String? mainPath,
    String? route,
    required fl.DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs = const {},
    bool prebuiltApplication = false,
    String? userIdentifier,
  }) {
    if (startAppFn != null) {
      return startAppFn!(
        package,
        mainPath: mainPath,
        route: route,
        debuggingOptions: debuggingOptions,
        platformArgs: platformArgs,
        prebuiltApplication: prebuiltApplication,
        userIdentifier: userIdentifier,
      );
    }
    fail('Should not access startApp');
  }

  @override
  Future<bool> stopApp(fl.ApplicationPackage? app, {String? userIdentifier}) {
    if (stopAppFn != null) {
      return stopAppFn!(app, userIdentifier: userIdentifier);
    }
    fail('Should not access stopApp');
  }

  @override
  Future<String> supportMessage() {
    if (supportMessageFn != null) return supportMessageFn!();
    fail('Should not access supportMessage');
  }

  @override
  Future<void> takeScreenshot(fl.File outputFile) {
    if (takeScreenshotFn != null) return takeScreenshotFn!(outputFile);
    fail('Should not access takeScreenshot');
  }

  @override
  FutureOr<bool> supportsRuntimeMode(fl.BuildMode buildMode) {
    if (supportsRuntimeModeFn != null) return supportsRuntimeModeFn!(buildMode);
    fail('Should not access supportsRuntimeMode');
  }

  @override
  Future<Map<String, Object>> toJson() {
    if (toJsonFn != null) return toJsonFn!();
    fail('Should not access toJson');
  }

  @override
  Future<bool> uninstallApp(
    fl.ApplicationPackage app, {
    String? userIdentifier,
  }) {
    if (uninstallAppFn != null) {
      return uninstallAppFn!(app, userIdentifier: userIdentifier);
    }
    fail('Should not access uninstallApp');
  }

  @override
  Uri? devToolsUri;
}
