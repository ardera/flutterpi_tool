import 'package:file/src/interface/directory.dart';
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:test/test.dart';

class MockAppBuilder implements AppBuilder {
  Future<void> Function({
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required fl.BuildInfo buildInfo,
    fl.FlutterProject? project,
    FlutterpiArtifacts? artifacts,
    String? mainPath,
    String manifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    Directory? outDir,
    bool unoptimized,
    bool includeDebugSymbols,
  })? buildFn;

  @override
  Future<void> build({
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required fl.BuildInfo buildInfo,
    fl.FlutterProject? project,
    FlutterpiArtifacts? artifacts,
    String? mainPath,
    String manifestPath = fl.defaultManifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    Directory? outDir,
    bool unoptimized = false,
    bool includeDebugSymbols = false,
  }) {
    if (buildFn == null) {
      fail("Expected buildFn to not be called.");
    }

    return buildFn!(
      host: host,
      target: target,
      buildInfo: buildInfo,
      project: project,
      artifacts: artifacts,
      mainPath: mainPath,
      manifestPath: manifestPath,
      applicationKernelFilePath: applicationKernelFilePath,
      depfilePath: depfilePath,
      outDir: outDir,
      unoptimized: unoptimized,
      includeDebugSymbols: includeDebugSymbols,
    );
  }

  Future<FlutterpiAppBundle> Function({
    required String id,
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required fl.BuildInfo buildInfo,
    fl.FlutterProject? project,
    FlutterpiArtifacts? artifacts,
    String? mainPath,
    String manifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    bool unoptimized,
    bool includeDebugSymbols,
  })? buildBundleFn;

  @override
  Future<FlutterpiAppBundle> buildBundle({
    required String id,
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required fl.BuildInfo buildInfo,
    fl.FlutterProject? project,
    FlutterpiArtifacts? artifacts,
    String? mainPath,
    String manifestPath = fl.defaultManifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    bool unoptimized = false,
    bool includeDebugSymbols = false,
  }) {
    if (buildBundleFn == null) {
      fail("Expected buildBundleFn to not be called.");
    }

    return buildBundleFn!(
      id: id,
      host: host,
      target: target,
      buildInfo: buildInfo,
      project: project,
      artifacts: artifacts,
      mainPath: mainPath,
      manifestPath: manifestPath,
      applicationKernelFilePath: applicationKernelFilePath,
      depfilePath: depfilePath,
      unoptimized: unoptimized,
      includeDebugSymbols: includeDebugSymbols,
    );
  }
}
