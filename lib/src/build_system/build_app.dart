// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/build_system/extended_environment.dart';
import 'package:flutterpi_tool/src/build_system/targets.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:unified_analytics/unified_analytics.dart';

Future<FlutterpiAppBundle> buildFlutterpiApp({
  required String id,
  required FlutterpiHostPlatform host,
  required FlutterpiTargetPlatform target,
  required BuildInfo buildInfo,
  required FlutterpiArtifactPaths artifactPaths,
  required MoreOperatingSystemUtils operatingSystemUtils,
  FlutterProject? project,
  String? mainPath,
  String manifestPath = defaultManifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  Artifacts? artifacts,
  BuildSystem? buildSystem,
  bool unoptimized = false,
  bool includeDebugSymbols = false,
}) async {
  final buildDir = getBuildDirectory();

  final outPath =
      globals.fs.path.join(buildDir, 'flutter-pi', target.toString());
  final outDir = globals.fs.directory(outPath);

  await buildFlutterpiBundle(
    host: host,
    target: target,
    buildInfo: buildInfo,
    artifactPaths: artifactPaths,
    outDir: outDir,
    operatingSystemUtils: operatingSystemUtils,
  );

  return PrebuiltFlutterpiAppBundle(
    id: id,
    name: id,
    displayName: id,
    directory: outDir,

    // FIXME: This should be populated by the build targets instead.
    binaries: [
      outDir.childFile('flutter-pi'),
      outDir.childFile('libflutter_engine.so'),
      if (outDir.childFile('libflutter_engine.so.dbgsyms').existsSync())
        outDir.childFile('libflutter_engine.so.dbgsyms'),
    ],
  );
}

Future<void> buildFlutterpiBundle({
  required FlutterpiHostPlatform host,
  required FlutterpiTargetPlatform target,
  required BuildInfo buildInfo,
  required FlutterpiArtifactPaths artifactPaths,
  required MoreOperatingSystemUtils operatingSystemUtils,
  FlutterProject? project,
  String? mainPath,
  String manifestPath = defaultManifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  Directory? outDir,
  Artifacts? artifacts,
  BuildSystem? buildSystem,
  bool unoptimized = false,
  bool includeDebugSymbols = false,
}) async {
  project ??= FlutterProject.current();
  mainPath ??= defaultMainPath;
  depfilePath ??= defaultDepfilePath;
  buildSystem ??= globals.buildSystem;
  outDir ??= globals.fs.directory(getAssetBuildDirectory());

  artifacts = OverrideGenSnapshotArtifacts.fromArtifactPaths(
    parent: artifacts ?? globals.artifacts!,
    engineCacheDir: flutterpiCache.getArtifactDirectory('engine'),
    host: host,
    target: target.genericVariant,
    artifactPaths: artifactPaths,
  );

  // We can still build debug for non-generic platforms of course, the correct
  // (generic) target must be chosen in the caller in that case.
  if (!target.isGeneric && buildInfo.mode == BuildMode.debug) {
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
    flutterRootDir: globals.fs.directory(Cache.flutterRoot),
    engineVersion: globals.artifacts!.usesLocalArtifacts
        ? null
        : globals.flutterVersion.engineRevision,
    analytics: NoOpAnalytics(),
    defines: <String, String>{
      if (includeDebugSymbols) kExtraGenSnapshotOptions: '--no-strip',

      // used by the KernelSnapshot target
      kTargetPlatform: getNameForTargetPlatform(TargetPlatform.linux_arm64),
      kTargetFile: mainPath,
      kDeferredComponents: 'false',
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
    usage: globals.flutterUsage,
    platform: globals.platform,
    generateDartPluginRegistry: true,
    operatingSystemUtils: operatingSystemUtils,
  );

  final buildTarget = switch (buildInfo.mode) {
    BuildMode.debug => DebugBundleFlutterpiAssets(
        flutterpiTargetPlatform: target,
        hostPlatform: host,
        unoptimized: unoptimized,
        artifactPaths: artifactPaths,
        debugSymbols: includeDebugSymbols,
      ),
    BuildMode.profile => ProfileBundleFlutterpiAssets(
        flutterpiTargetPlatform: target,
        hostPlatform: host,
        artifactPaths: artifactPaths,
        debugSymbols: includeDebugSymbols,
      ),
    BuildMode.release => ReleaseBundleFlutterpiAssets(
        flutterpiTargetPlatform: target,
        hostPlatform: host,
        artifactPaths: artifactPaths,
        debugSymbols: includeDebugSymbols,
      ),
    _ => throwToolExit('Unsupported build mode: ${buildInfo.mode}'),
  };

  final status = globals.logger.startProgress('Building Flutter-Pi bundle...');

  try {
    final result = await buildSystem.build(buildTarget, environment);
    if (!result.success) {
      for (final measurement in result.exceptions.values) {
        globals.printError(
          'Target ${measurement.target} failed: ${measurement.exception}',
          stackTrace: measurement.fatal ? measurement.stackTrace : null,
        );
      }

      throwToolExit('Failed to build bundle.');
    }

    final depfile = Depfile(result.inputFiles, result.outputFiles);
    final outputDepfile = globals.fs.file(depfilePath);
    if (!outputDepfile.parent.existsSync()) {
      outputDepfile.parent.createSync(recursive: true);
    }

    final depfileService = DepfileService(
      fileSystem: globals.fs,
      logger: globals.logger,
    );
    depfileService.writeToFile(depfile, outputDepfile);
  } finally {
    status.cancel();
  }

  return;
}
