import 'package:file/file.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

class FlutterpiApplicationPackageFactory
    implements FlutterApplicationPackageFactory {
  @override
  Future<ApplicationPackage?> getPackageForPlatform(
    TargetPlatform platform, {
    BuildInfo? buildInfo,
    File? applicationBinary,
  }) async {
    switch (platform) {
      case TargetPlatform.linux_arm64:
      case TargetPlatform.linux_x64:
        final flutterProject = FlutterProject.current();

        return BuildableFlutterpiAppBundle(
          id: flutterProject.manifest.appName,
          name: flutterProject.manifest.appName,
          displayName: flutterProject.manifest.appName,
        );
      default:
        return null;
    }
  }
}
