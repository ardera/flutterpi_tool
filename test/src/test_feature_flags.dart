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
    this.isExplicitPackageDependenciesEnabled = false,
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
  final bool isExplicitPackageDependenciesEnabled;

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
      fl.explicitPackageDependencies => isExplicitPackageDependenciesEnabled,
      _ => false,
    };
  }
}
