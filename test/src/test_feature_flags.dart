import 'package:flutterpi_tool/src/fltool/common.dart' as fl;

class TestFeatureFlags implements fl.FeatureFlags {
  TestFeatureFlags({
    this.isLinuxEnabled = false,
    this.isMacOSEnabled = false,
    this.isWebEnabled = false,
    this.isWindowsEnabled = false,
    this.isAndroidEnabled = true,
    this.isIOSEnabled = true,
    this.isFuchsiaEnabled = false,
    this.areCustomDevicesEnabled = false,
    this.isCliAnimationEnabled = true,
    this.isNativeAssetsEnabled = false,
    this.isSwiftPackageManagerEnabled = false,
    this.isOmitLegacyVersionFileEnabled = false,
    this.isLLDBDebuggingEnabled = false,
    this.isDartDataAssetsEnabled = false,
    this.isUISceneMigrationEnabled = false,
    this.isWindowingEnabled = false,
  });

  @override
  final bool isLinuxEnabled;

  @override
  final bool isMacOSEnabled;

  @override
  final bool isWebEnabled;

  @override
  final bool isWindowsEnabled;

  @override
  final bool isAndroidEnabled;

  @override
  final bool isIOSEnabled;

  @override
  final bool isFuchsiaEnabled;

  @override
  final bool areCustomDevicesEnabled;

  @override
  final bool isCliAnimationEnabled;

  @override
  final bool isNativeAssetsEnabled;

  @override
  final bool isSwiftPackageManagerEnabled;

  @override
  final bool isOmitLegacyVersionFileEnabled;

  @override
  final bool isLLDBDebuggingEnabled;

  @override
  final bool isDartDataAssetsEnabled;

  @override
  final bool isUISceneMigrationEnabled;

  @override
  final bool isWindowingEnabled;

  @override
  bool isEnabled(fl.Feature feature) {
    return switch (feature) {
      fl.flutterWebFeature => isWebEnabled,
      fl.flutterLinuxDesktopFeature => isLinuxEnabled,
      fl.flutterMacOSDesktopFeature => isMacOSEnabled,
      fl.flutterWindowsDesktopFeature => isWindowsEnabled,
      fl.flutterAndroidFeature => isAndroidEnabled,
      fl.flutterIOSFeature => isIOSEnabled,
      fl.flutterFuchsiaFeature => isFuchsiaEnabled,
      fl.flutterCustomDevicesFeature => areCustomDevicesEnabled,
      fl.cliAnimation => isCliAnimationEnabled,
      fl.nativeAssets => isNativeAssetsEnabled,
      fl.swiftPackageManager => isSwiftPackageManagerEnabled,
      fl.omitLegacyVersionFile => isOmitLegacyVersionFileEnabled,
      fl.lldbDebugging => isLLDBDebuggingEnabled,
      fl.dartDataAssets => isDartDataAssetsEnabled,
      fl.uiSceneMigration => isUISceneMigrationEnabled,
      fl.windowingFeature => isWindowingEnabled,
      _ => false,
    };
  }

  @override
  List<fl.Feature> get allFeatures => const <fl.Feature>[
        fl.flutterWebFeature,
        fl.flutterLinuxDesktopFeature,
        fl.flutterMacOSDesktopFeature,
        fl.flutterWindowsDesktopFeature,
        fl.flutterAndroidFeature,
        fl.flutterIOSFeature,
        fl.flutterFuchsiaFeature,
        fl.flutterCustomDevicesFeature,
        fl.cliAnimation,
        fl.nativeAssets,
        fl.swiftPackageManager,
        fl.omitLegacyVersionFile,
        fl.lldbDebugging,
        fl.dartDataAssets,
        fl.uiSceneMigration,
        fl.windowingFeature,
      ];

  @override
  Iterable<fl.Feature> get allConfigurableFeatures {
    return allFeatures
        .where((fl.Feature feature) => feature.configSetting != null);
  }

  @override
  Iterable<fl.Feature> get allEnabledFeatures {
    return allFeatures.where(isEnabled);
  }
}
