import 'package:file/file.dart';
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/extended_environment.dart';
import 'package:flutterpi_tool/src/build_system/targets.dart';
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

class AppBuilder {
  AppBuilder({
    MoreOperatingSystemUtils? operatingSystemUtils,
    fl.BuildSystem? buildSystem,
  })  : _buildSystem = buildSystem ?? globals.buildSystem,
        _operatingSystemUtils = operatingSystemUtils ?? globals.moreOs;

  final MoreOperatingSystemUtils _operatingSystemUtils;
  final fl.BuildSystem _buildSystem;

  Future<void> build({
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required fl.BuildInfo buildInfo,
    required FilesystemLayout fsLayout,
    fl.FlutterProject? project,
    FlutterpiArtifacts? artifacts,
    String? mainPath,
    String manifestPath = fl.defaultManifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    Directory? outDir,
    bool unoptimized = false,
    bool includeDebugSymbols = false,
    bool forceBundleFlutterpi = false,
  }) async {
    project ??= fl.FlutterProject.current();
    mainPath ??= fl.defaultMainPath;
    depfilePath ??= fl.defaultDepfilePath;
    outDir ??= globals.fs.directory(
      globals.fs.path.join(
        fl.getBuildDirectory(),
        'flutter-pi',
        switch (fsLayout) {
          FilesystemLayout.flutterPi => '$target',
          FilesystemLayout.metaFlutter => 'meta-flutter-$target',
        },
      ),
    );
    artifacts ??= globals.flutterpiArtifacts;

    // We can still build debug for non-generic platforms of course, the correct
    // (generic) target must be chosen in the caller in that case.
    if (!target.isGeneric && buildInfo.mode == fl.BuildMode.debug) {
      throw ArgumentError.value(
        buildInfo,
        'buildInfo',
        'Non-generic targets are not supported for debug mode.',
      );
    }

    // If the precompiled flag was not passed, force us into debug mode.
    final environment = ExtendedEnvironment(
      projectDir: project.directory,
      packageConfigPath: buildInfo.packageConfigPath,
      outputDir: outDir,
      buildDir: project.dartTool.childDirectory('flutter_build'),
      cacheDir: globals.cache.getRoot(),
      flutterRootDir: globals.fs.directory(fl.Cache.flutterRoot),
      engineVersion: globals.artifacts!.usesLocalArtifacts
          ? null
          : globals.flutterVersion.engineRevision,
      analytics: NoOpAnalytics(),
      defines: <String, String>{
        if (includeDebugSymbols) fl.kExtraGenSnapshotOptions: '--no-strip',

        // used by the KernelSnapshot target
        fl.kTargetPlatform:
            fl.getNameForTargetPlatform(fl.TargetPlatform.linux_arm64),
        fl.kTargetFile: mainPath,
        fl.kDeferredComponents: 'false',
        ...buildInfo.toBuildSystemEnvironment(),

        // The flutter_tool computes the `.dart_tool/` subdir name from the
        // build environment hash.
        // Adding a flutterpi-target entry here forces different subdirs for
        // different target platforms.
        //
        // If we don't have this, the flutter tool will happily reuse as much as
        // it can, and it determines it can reuse the `app.so` from (for example)
        // an arm build with an arm64 build, leading to errors.
        'flutterpi-target': target.shortName,
        'unoptimized': unoptimized.toString(),
        'debug-symbols': includeDebugSymbols.toString(),
      },
      artifacts: artifacts,
      fileSystem: globals.fs,
      logger: globals.logger,
      processManager: globals.processManager,
      platform: globals.platform,
      generateDartPluginRegistry: true,
      operatingSystemUtils: _operatingSystemUtils,
    );

    final buildTarget = switch (buildInfo.mode) {
      fl.BuildMode.debug => DebugBundleFlutterpiAssets(
          target: target,
          unoptimized: unoptimized,
          debugSymbols: includeDebugSymbols,
          layout: fsLayout,
          forceBundleFlutterpi: forceBundleFlutterpi,
        ),
      fl.BuildMode.profile => ProfileBundleFlutterpiAssets(
          target: target,
          debugSymbols: includeDebugSymbols,
          layout: fsLayout,
          forceBundleFlutterpi: forceBundleFlutterpi,
        ),
      fl.BuildMode.release => ReleaseBundleFlutterpiAssets(
          target: target,
          debugSymbols: includeDebugSymbols,
          layout: fsLayout,
          forceBundleFlutterpi: forceBundleFlutterpi,
        ),
      _ => fl.throwToolExit('Unsupported build mode: ${buildInfo.mode}'),
    };

    final status =
        globals.logger.startProgress('Building Flutter-Pi bundle...');

    try {
      final result = await _buildSystem.build(buildTarget, environment);
      if (!result.success) {
        for (final measurement in result.exceptions.values) {
          globals.printError(
            'Target ${measurement.target} failed: ${measurement.exception}',
            stackTrace: measurement.fatal ? measurement.stackTrace : null,
          );
        }

        fl.throwToolExit('Failed to build bundle.');
      }

      final depfile = fl.Depfile(result.inputFiles, result.outputFiles);
      final outputDepfile = globals.fs.file(depfilePath);
      if (!outputDepfile.parent.existsSync()) {
        outputDepfile.parent.createSync(recursive: true);
      }

      final depfileService = fl.DepfileService(
        fileSystem: globals.fs,
        logger: globals.logger,
      );
      depfileService.writeToFile(depfile, outputDepfile);
    } finally {
      status.cancel();
    }

    return;
  }

  Future<FlutterpiAppBundle> buildBundle({
    required String id,
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required fl.BuildInfo buildInfo,
    required FilesystemLayout fsLayout,
    fl.FlutterProject? project,
    FlutterpiArtifacts? artifacts,
    String? mainPath,
    String manifestPath = fl.defaultManifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    bool unoptimized = false,
    bool includeDebugSymbols = false,
    bool forceBundleFlutterpi = false,
  }) async {
    final buildDir = fl.getBuildDirectory();

    final outPath = globals.fs.directory(
      globals.fs.path.join(
        buildDir,
        'flutter-pi',
        switch (fsLayout) {
          FilesystemLayout.flutterPi => '$target',
          FilesystemLayout.metaFlutter => 'meta-flutter-$target',
        },
      ),
    );
    final outDir = globals.fs.directory(outPath);

    await build(
      host: host,
      target: target,
      buildInfo: buildInfo,
      fsLayout: fsLayout,
      artifacts: artifacts,
      mainPath: mainPath,
      manifestPath: manifestPath,
      applicationKernelFilePath: applicationKernelFilePath,
      depfilePath: depfilePath,
      outDir: outDir,
      unoptimized: unoptimized,
      includeDebugSymbols: includeDebugSymbols,
      forceBundleFlutterpi: forceBundleFlutterpi,
    );

    final metaFlutterFlutterpiBin =
        outDir.childDirectory('bin').childFile('flutter-pi');
    final metaFlutterDbgsyms =
        outDir.childDirectory('lib').childFile('libflutter_engine.dbgsyms');

    return PrebuiltFlutterpiAppBundle(
      id: id,
      name: id,
      displayName: id,
      directory: outDir,

      // FIXME: This should be populated by the build targets instead.
      binaries: switch (fsLayout) {
        FilesystemLayout.flutterPi => [
            outDir.childFile('flutter-pi'),
            outDir.childFile('libflutter_engine.so'),
            if (includeDebugSymbols)
              outDir.childFile('libflutter_engine.so.dbgsyms'),
          ],
        FilesystemLayout.metaFlutter => [
            if (forceBundleFlutterpi) metaFlutterFlutterpiBin,
            outDir.childDirectory('lib').childFile('libflutter_engine.so'),
            if (includeDebugSymbols) metaFlutterDbgsyms,
          ],
      },

      includesFlutterpiBinary:
          fsLayout == FilesystemLayout.flutterPi || forceBundleFlutterpi,
    );
  }
}
