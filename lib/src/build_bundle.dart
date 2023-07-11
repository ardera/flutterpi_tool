// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_tools/src/bundle.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/context_runner.dart' as context_runner;
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:github/github.dart' as gh;

import 'package:package_config/package_config.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;

enum FlutterpiTargetPlatform {
  genericArmV7('generic-armv7'),
  genericAArch64('generic-aarch64'),
  pi3('pi3'),
  pi3_64('pi3-64'),
  pi4('pi4'),
  pi4_64('pi4-64');

  const FlutterpiTargetPlatform(this.shortName);

  final String shortName;
}

class FlutterpiCache extends FlutterCache {
  FlutterpiCache({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required OperatingSystemUtils osUtils,
    required super.projectFactory,
    Set<FlutterpiTargetPlatform> flutterpiPlatforms = const {
      FlutterpiTargetPlatform.genericArmV7,
      FlutterpiTargetPlatform.genericAArch64
    },
  })  : _logger = logger,
        _fileSystem = fileSystem,
        _platform = platform,
        _osUtils = osUtils,
        super(
          logger: logger,
          platform: platform,
          fileSystem: fileSystem,
          osUtils: osUtils,
        ) {
    registerArtifact(FlutterpiEngineBinaries(
      this,
      platform: platform,
      flutterpiPlatforms: flutterpiPlatforms,
    ));
  }

  final Logger _logger;
  final FileSystem _fileSystem;
  final Platform _platform;
  final OperatingSystemUtils _osUtils;
  final List<ArtifactSet> _artifacts = [];

  @override
  void registerArtifact(ArtifactSet artifactSet) {
    _artifacts.add(artifactSet);
    super.registerArtifact(artifactSet);
  }

  final flutterPiEngineCi = gh.RepositorySlug('ardera', 'flutter-ci');

  late final ArtifactUpdater _artifactUpdater = _createUpdater();

  final flutterpiCiBaseUrl = 'https://github.com/ardera/flutter-ci/';

  /// This has to be lazy because it requires FLUTTER_ROOT to be initialized.
  ArtifactUpdater _createUpdater() {
    return ArtifactUpdater(
      operatingSystemUtils: _osUtils,
      logger: _logger,
      fileSystem: _fileSystem,
      tempStorage: getDownloadDir(),
      platform: _platform,
      httpClient: io.HttpClient(),
      allowedBaseUrls: <String>[storageBaseUrl, cipdBaseUrl, flutterpiCiBaseUrl],
    );
  }

  /// Update the cache to contain all `requiredArtifacts`.
  @override
  Future<void> updateAll(
    Set<DevelopmentArtifact> requiredArtifacts, {
    bool offline = false,
  }) async {
    for (final ArtifactSet artifact in _artifacts) {
      if (!requiredArtifacts.contains(artifact.developmentArtifact)) {
        _logger.printTrace('Artifact $artifact is not required, skipping update.');
        continue;
      }

      if (await artifact.isUpToDate(_fileSystem)) {
        continue;
      }

      await artifact.update(
        _artifactUpdater,
        _logger,
        _fileSystem,
        _osUtils,
        offline: offline,
      );
    }
  }
}

class FlutterpiArtifactPaths {
  String getTargetDirName(FlutterpiTargetPlatform target) {
    return switch (target) {
      FlutterpiTargetPlatform.genericArmV7 => 'flutterpi-armv7-generic',
      FlutterpiTargetPlatform.genericAArch64 => 'flutterpi-aarch64-generic',
      FlutterpiTargetPlatform.pi3 => 'flutterpi-pi3',
      FlutterpiTargetPlatform.pi3_64 => 'flutterpi-pi3-64',
      FlutterpiTargetPlatform.pi4 => 'flutterpi-pi4',
      FlutterpiTargetPlatform.pi4_64 => 'flutterpi-pi4-64',
    };
  }

  String getHostDirName(HostPlatform hostPlatform) {
    return switch (hostPlatform) {
      HostPlatform.linux_x64 => 'linux-x64',
      _ => throw UnsupportedError('Unsupported host platform: $hostPlatform'),
    };
  }

  String getGenSnapshotFilename(HostPlatform hostPlatform, BuildMode buildMode) {
    return switch ((hostPlatform, buildMode)) {
      (HostPlatform.linux_x64, BuildMode.profile) => 'gen_snapshot_linux_x64_profile',
      (HostPlatform.linux_x64, BuildMode.release) => 'gen_snapshot_linux_x64_release',
      _ => throw UnsupportedError('Unsupported host platform & build mode combinations: $hostPlatform, $buildMode'),
    };
  }

  String getEngineFilename(BuildMode buildMode, {bool unoptimized = false}) {
    return switch ((buildMode, unoptimized)) {
      (BuildMode.debug, true) => 'libflutter_engine.so.debug_unopt',
      (BuildMode.debug, false) => 'libflutter_engine.so.debug',
      (BuildMode.profile, false) => 'libflutter_engine.so.profile',
      (BuildMode.release, false) => 'libflutter_engine.so.release',
      _ => throw UnsupportedError('Unsupported build mode: $buildMode'),
    };
  }

  File getEngine({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    return engineCacheDir
        .childDirectory(getTargetDirName(flutterpiTargetPlatform))
        .childDirectory(getHostDirName(hostPlatform))
        .childFile(getEngineFilename(buildMode, unoptimized: unoptimized));
  }

  File getGenSnapshot({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    return engineCacheDir
        .childDirectory(getTargetDirName(flutterpiTargetPlatform))
        .childDirectory(getHostDirName(hostPlatform))
        .childFile(getGenSnapshotFilename(hostPlatform, buildMode));
  }

  Source getEngineSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    final targetDirName = getTargetDirName(flutterpiTargetPlatform);
    final hostDirName = getHostDirName(hostPlatform);
    final engineFileName = getEngineFilename(buildMode, unoptimized: unoptimized);

    return Source.pattern('{CACHE_DIR}/artifacts/$artifactSubDir/$targetDirName/$hostDirName/$engineFileName');
  }
}

abstract class FlutterpiEngineCIArtifact extends EngineCachedArtifact {
  FlutterpiEngineCIArtifact(
    String stampName,
    FlutterpiCache cache,
    DevelopmentArtifact developmentArtifact,
  ) : super(stampName, cache, developmentArtifact);

  // @override
  // final String stampName;

  @override
  FlutterpiCache get cache => super.cache as FlutterpiCache;

  /// Return a list of (directory path, download URL path) tuples.
  // List<List<String>> getBinaryDirs();

  /// A list of cache directory paths to which the LICENSE file should be copied.
  // List<String> getLicenseDirs();

  /// A list of the dart package directories to download.
  // List<String> getPackageDirs();

  @override
  bool isUpToDateInner(FileSystem fileSystem) {
    final Directory pkgDir = cache.getCacheDir('pkg');
    for (final String pkgName in getPackageDirs()) {
      final String pkgPath = fileSystem.path.join(pkgDir.path, pkgName);
      if (!fileSystem.directory(pkgPath).existsSync()) {
        return false;
      }
    }

    for (final List<String> toolsDir in getBinaryDirs()) {
      final Directory dir = fileSystem.directory(fileSystem.path.join(location.path, toolsDir[0]));
      if (!dir.existsSync()) {
        return false;
      }
    }

    for (final String licenseDir in getLicenseDirs()) {
      final File file = fileSystem.file(fileSystem.path.join(location.path, licenseDir, 'LICENSE'));
      if (!file.existsSync()) {
        return false;
      }
    }
    return true;
  }

  Future<gh.Release> findGithubReleaseByEngineHash(String hash) async {
    var tagName = 'engine/$hash';

    return await gh.GitHub().repositories.getReleaseByTagName(cache.flutterPiEngineCi, tagName);
  }

  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    late gh.Release ghRelease;
    try {
      ghRelease = await findGithubReleaseByEngineHash(version!);
    } on gh.ReleaseNotFound {
      throwToolExit('Flutter engine binaries for engine $version are not available.');
    }

    for (final List<String> dirs in getBinaryDirs()) {
      final cacheDir = dirs[0];
      final urlPath = dirs[1];

      final ghAsset =
          ghRelease.assets!.cast<gh.ReleaseAsset?>().singleWhere((asset) => asset!.name == urlPath, orElse: () => null);
      if (ghAsset == null) {
        throwToolExit('Flutter engine binaries with version $version and target $urlPath are not available.');
      }

      final downloadUrl = ghAsset.browserDownloadUrl!;

      final destDir = fileSystem.directory(fileSystem.path.join(location.path, cacheDir));

      await artifactUpdater.downloadZippedTarball(
        'Downloading $urlPath tools...',
        Uri.parse(downloadUrl),
        destDir,
      );

      _makeFilesExecutable(destDir, operatingSystemUtils);
    }
  }

  @override
  Future<bool> checkForArtifacts(String? engineVersion) async {
    try {
      await findGithubReleaseByEngineHash(version!);
      return true;
    } on gh.ReleaseNotFound {
      return false;
    }
  }

  void _makeFilesExecutable(
    Directory dir,
    OperatingSystemUtils operatingSystemUtils,
  ) {
    operatingSystemUtils.chmod(dir, 'a+r,a+x');

    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      final stat = file.statSync();

      final isUserExecutable = ((stat.mode >> 6) & 0x1) == 1;
      if (file.basename == 'flutter_tester' || isUserExecutable) {
        // Make the file readable and executable by all users.
        operatingSystemUtils.chmod(file, 'a+r,a+x');
      }

      if (file.basename.startsWith('gen_snapshot_')) {
        operatingSystemUtils.chmod(file, 'a+r,a+x');
      }
    }
  }
}

class FlutterpiEngineBinaries extends FlutterpiEngineCIArtifact {
  FlutterpiEngineBinaries(
    FlutterpiCache cache, {
    required Platform platform,
    this.flutterpiPlatforms = const {FlutterpiTargetPlatform.genericArmV7, FlutterpiTargetPlatform.genericAArch64},
  })  : _platform = platform,
        super(
          'flutterpi-engine-binaries',
          cache,
          DevelopmentArtifact.universal,
        );

  final Platform _platform;

  final Set<FlutterpiTargetPlatform> flutterpiPlatforms;

  @override
  List<String> getPackageDirs() => const <String>[];

  @override
  List<List<String>> getBinaryDirs() {
    if (!_platform.isLinux) {
      return [];
    }

    return [
      if (flutterpiPlatforms.contains(FlutterpiTargetPlatform.genericAArch64))
        ['flutterpi-aarch64-generic/linux-x64', 'aarch64-generic.tar.xz'],
      if (flutterpiPlatforms.contains(FlutterpiTargetPlatform.genericArmV7))
        ['flutterpi-armv7-generic/linux-x64', 'armv7-generic.tar.xz'],
      if (flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi3)) ['flutterpi-pi3/linux-x64', 'pi3.tar.xz'],
      if (flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi3_64)) ['flutterpi-pi3-64/linux-x64', 'pi3-64.tar.xz'],
      if (flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi4)) ['flutterpi-pi4/linux-x64', 'pi4.tar.xz'],
      if (flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi4_64)) ['flutterpi-pi4-64/linux-x64', 'pi4-64.tar.xz'],
    ];
  }

  @override
  List<String> getLicenseDirs() {
    return <String>[];
  }
}

class TarXzCompatibleOsUtils implements OperatingSystemUtils {
  TarXzCompatibleOsUtils({
    required OperatingSystemUtils os,
    required ProcessUtils processUtils,
  })  : _os = os,
        _processUtils = processUtils;

  final OperatingSystemUtils _os;
  final ProcessUtils _processUtils;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    return _os.chmod(entity, mode);
  }

  @override
  Future<int> findFreePort({bool ipv6 = false}) {
    return _os.findFreePort(ipv6: false);
  }

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) {
    return _os.gzipLevel1Stream(stream);
  }

  @override
  HostPlatform get hostPlatform => _os.hostPlatform;

  @override
  void makeExecutable(File file) => _os.makeExecutable(file);

  @override
  File makePipe(String path) => _os.makePipe(path);

  @override
  String get name => _os.name;

  @override
  String get pathVarSeparator => _os.pathVarSeparator;

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory) {
    _processUtils.runSync(
      <String>['tar', '-xf', gzippedTarFile.path, '-C', targetDirectory.path],
      throwOnError: true,
    );
  }

  @override
  void unzip(File file, Directory targetDirectory) {
    _os.unzip(file, targetDirectory);
  }

  @override
  File? which(String execName) {
    return _os.which(execName);
  }

  @override
  List<File> whichAll(String execName) {
    return _os.whichAll(execName);
  }
}

/// Copies the kernel_blob.bin to the output directory.
class CopyFlutterAssets extends CopyFlutterBundle {
  const CopyFlutterAssets();

  @override
  String get name => 'bundle_flutterpi_assets';
}

/// A wrapper for AOT compilation that copies app.so into the output directory.
class FlutterpiAppElf extends Target {
  /// Create a [FlutterpiAppElf] wrapper for [aotTarget].
  const FlutterpiAppElf(this.aotTarget);

  /// The [AotElfBase] subclass that produces the app.so.
  final AotElfBase aotTarget;

  @override
  String get name => 'flutterpi_aot_bundle';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/app.so'),
      ];

  @override
  List<Target> get dependencies => <Target>[
        aotTarget,
      ];

  @override
  Future<void> build(Environment environment) async {
    final File outputFile = environment.buildDir.childFile('app.so');
    outputFile.copySync(environment.outputDir.childFile('app.so').path);
  }
}

class CopyFlutterpiEngine extends Target {
  const CopyFlutterpiEngine(
    this.flutterpiTargetPlatform, {
    required BuildMode buildMode,
    required HostPlatform hostPlatform,
    bool unoptimized = false,
    required FlutterpiArtifactPaths artifactPaths,
  })  : _buildMode = buildMode,
        _hostPlatform = hostPlatform,
        _unoptimized = unoptimized,
        _artifactPaths = artifactPaths;

  final FlutterpiTargetPlatform flutterpiTargetPlatform;
  final BuildMode _buildMode;
  final HostPlatform _hostPlatform;
  final bool _unoptimized;
  final FlutterpiArtifactPaths _artifactPaths;

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => [
        _artifactPaths.getEngineSource(
          hostPlatform: _hostPlatform,
          flutterpiTargetPlatform: flutterpiTargetPlatform,
          buildMode: _buildMode,
          unoptimized: _unoptimized,
        )
      ];

  @override
  String get name =>
      'copy_flutterpi_engine_${flutterpiTargetPlatform.shortName}_$_buildMode${_unoptimized ? '_unopt' : ''}';

  @override
  List<Source> get outputs => [
        const Source.pattern('{OUTPUT_DIR}/libflutter_engine.so'),
      ];

  @override
  Future<void> build(Environment environment) async {
    final outputFile = environment.outputDir.childFile('libflutter_engine.so');
    if (!outputFile.parent.existsSync()) {
      outputFile.parent.createSync(recursive: true);
    }

    _artifactPaths
        .getEngine(
          engineCacheDir: environment.cacheDir.childDirectory('artifacts').childDirectory('engine'),
          hostPlatform: _hostPlatform,
          flutterpiTargetPlatform: flutterpiTargetPlatform,
          buildMode: _buildMode,
        )
        .copySync(outputFile.path);
  }
}

class CopyIcudtl extends Target {
  const CopyIcudtl();

  @override
  String get name => 'flutterpi_copy_icudtl';

  @override
  List<Source> get inputs => const <Source>[
        Source.artifact(Artifact.icuData),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/icudtl.dat'),
      ];

  @override
  List<Target> get dependencies => [];

  @override
  Future<void> build(Environment environment) async {
    final icudtl = environment.fileSystem.file(environment.artifacts.getArtifactPath(Artifact.icuData));
    final outputFile = environment.outputDir.childFile('icudtl.dat');
    icudtl.copySync(outputFile.path);
  }
}

class DebugBundleFlutterpiAssets extends CompositeTarget {
  DebugBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required HostPlatform hostPlatform,
    bool unoptimized = false,
    required FlutterpiArtifactPaths artifactPaths,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(
            flutterpiTargetPlatform,
            buildMode: BuildMode.debug,
            hostPlatform: hostPlatform,
            unoptimized: unoptimized,
            artifactPaths: artifactPaths,
          ),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'debug_bundle_flutterpi_assets';
}

class ProfileBundleFlutterpiAssets extends CompositeTarget {
  ProfileBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required HostPlatform hostPlatform,
    required FlutterpiArtifactPaths artifactPaths,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(
            flutterpiTargetPlatform,
            buildMode: BuildMode.profile,
            hostPlatform: hostPlatform,
            artifactPaths: artifactPaths,
          ),
          const FlutterpiAppElf(AotElfProfile(TargetPlatform.linux_arm64)),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'profile_bundle_flutterpi_${flutterpiTargetPlatform.shortName}_assets';
}

class ReleaseBundleFlutterpiAssets extends CompositeTarget {
  ReleaseBundleFlutterpiAssets({
    required this.flutterpiTargetPlatform,
    required HostPlatform hostPlatform,
    required FlutterpiArtifactPaths artifactPaths,
  }) : super([
          const CopyFlutterAssets(),
          const CopyIcudtl(),
          CopyFlutterpiEngine(
            flutterpiTargetPlatform,
            buildMode: BuildMode.release,
            hostPlatform: hostPlatform,
            artifactPaths: artifactPaths,
          ),
          const FlutterpiAppElf(AotElfRelease(TargetPlatform.linux_arm64)),
        ]);

  final FlutterpiTargetPlatform flutterpiTargetPlatform;

  @override
  String get name => 'release_bundle_flutterpi_${flutterpiTargetPlatform.shortName}_assets';
}

/// An implementation of [Artifacts] that provides individual overrides.
///
/// If an artifact is not provided, the lookup delegates to the parent.
class FlutterpiCachedGenSnapshotArtifacts implements Artifacts {
  /// Creates a new [OverrideArtifacts].
  ///
  /// [parent] must be provided.
  FlutterpiCachedGenSnapshotArtifacts({
    required this.parent,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required FileSystem fileSystem,
    required Platform platform,
    required Cache cache,
    required OperatingSystemUtils operatingSystemUtils,
  })  : _flutterpiTargetPlatform = flutterpiTargetPlatform,
        _fileSystem = fileSystem,
        _cache = cache,
        _operatingSystemUtils = operatingSystemUtils;

  final FileSystem _fileSystem;
  final Cache _cache;
  final OperatingSystemUtils _operatingSystemUtils;
  final FlutterpiTargetPlatform _flutterpiTargetPlatform;
  final Artifacts parent;

  @override
  LocalEngineInfo? get localEngineInfo => parent.localEngineInfo;

  String _getGenSnapshotPath(BuildMode buildMode) {
    final engineDir = _cache.getArtifactDirectory('engine').path;

    final hostPlatform = _operatingSystemUtils.hostPlatform;

    // Just some shorthands so the formatting doesn't look totally weird below.
    const genericArmv7 = FlutterpiTargetPlatform.genericArmV7;
    const genericAArch64 = FlutterpiTargetPlatform.genericAArch64;
    const pi3 = FlutterpiTargetPlatform.pi3;
    const pi3_64 = FlutterpiTargetPlatform.pi3_64;
    const pi4 = FlutterpiTargetPlatform.pi4;
    const pi4_64 = FlutterpiTargetPlatform.pi4_64;

    // ignore: constant_identifier_names
    const linux_x64 = HostPlatform.linux_x64;

    final subdir = switch ((_flutterpiTargetPlatform, hostPlatform)) {
      (genericArmv7, linux_x64) => const ['flutterpi-armv7-generic', 'linux-x64'],
      (genericAArch64, linux_x64) => const ['flutterpi-aarch64-generic', 'linux-x64'],
      (pi3, linux_x64) => const ['flutterpi-pi3', 'linux-x64'],
      (pi3_64, linux_x64) => const ['flutterpi-pi3-64', 'linux-x64'],
      (pi4, linux_x64) => const ['flutterpi-pi4', 'linux-x64'],
      (pi4_64, linux_x64) => const ['flutterpi-pi4-64', 'linux-x64'],
      _ => throw UnsupportedError(
          'Unsupported target platform & host platform combination: $_flutterpiTargetPlatform, $hostPlatform'),
    };

    final genSnapshotFilename = switch ((_operatingSystemUtils.hostPlatform, buildMode)) {
      (linux_x64, BuildMode.profile) => 'gen_snapshot_linux_x64_profile',
      (linux_x64, BuildMode.release) => 'gen_snapshot_linux_x64_release',
      _ => throw UnsupportedError('Unsupported host platform & build mode combinations: $hostPlatform, $buildMode'),
    };

    return _fileSystem.path.joinAll([engineDir, ...subdir, genSnapshotFilename]);
  }

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    if (artifact == Artifact.genSnapshot && (mode == BuildMode.profile || mode == BuildMode.release)) {
      return _getGenSnapshotPath(mode!);
    }
    return parent.getArtifactPath(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) => parent.getEngineType(platform, mode);

  @override
  bool get isLocalEngine => parent.isLocalEngine;

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    return parent.getHostArtifact(artifact);
  }
}

Future<String> getFlutterRoot() async {
  final pkgconfig = await findPackageConfigUri(io.Platform.script);
  pkgconfig!;

  final flutterToolsPath = pkgconfig.resolve(Uri.parse('package:flutter_tools/'))!.toFilePath();

  const dirname = path.dirname;

  return dirname(dirname(dirname(flutterToolsPath)));
}

Future<void> buildFlutterpiBundle({
  required FlutterpiTargetPlatform flutterpiTargetPlatform,
  required BuildInfo buildInfo,
  FlutterpiArtifactPaths? artifactPaths,
  FlutterProject? project,
  String? mainPath,
  String manifestPath = defaultManifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  String? assetDirPath,
  Artifacts? artifacts,
  BuildSystem? buildSystem,
  bool unoptimized = false,
}) async {
  project ??= FlutterProject.current();
  mainPath ??= defaultMainPath;
  depfilePath ??= defaultDepfilePath;
  assetDirPath ??= getAssetBuildDirectory();
  buildSystem ??= globals.buildSystem;
  artifacts ??= globals.artifacts!;
  artifactPaths ??= FlutterpiArtifactPaths();

  // If the precompiled flag was not passed, force us into debug mode.
  final environment = Environment(
    projectDir: project.directory,
    outputDir: globals.fs.directory(assetDirPath),
    buildDir: project.dartTool.childDirectory('flutter_build'),
    cacheDir: globals.cache.getRoot(),
    flutterRootDir: globals.fs.directory(Cache.flutterRoot),
    engineVersion: globals.artifacts!.isLocalEngine ? null : globals.flutterVersion.engineRevision,
    defines: <String, String>{
      // used by the KernelSnapshot target
      kTargetPlatform: getNameForTargetPlatform(TargetPlatform.linux_arm64),
      kTargetFile: mainPath,
      kDeferredComponents: 'false',
      ...buildInfo.toBuildSystemEnvironment(),
    },
    artifacts: artifacts,
    fileSystem: globals.fs,
    logger: globals.logger,
    processManager: globals.processManager,
    usage: globals.flutterUsage,
    platform: globals.platform,
    generateDartPluginRegistry: true,
  );

  final hostPlatform = globals.os.hostPlatform;

  final target = switch (buildInfo.mode) {
    BuildMode.debug => DebugBundleFlutterpiAssets(
        flutterpiTargetPlatform: flutterpiTargetPlatform,
        hostPlatform: hostPlatform,
        unoptimized: unoptimized,
        artifactPaths: artifactPaths,
      ),
    BuildMode.profile => ProfileBundleFlutterpiAssets(
        flutterpiTargetPlatform: flutterpiTargetPlatform,
        hostPlatform: hostPlatform,
        artifactPaths: artifactPaths,
      ),
    BuildMode.release => ReleaseBundleFlutterpiAssets(
        flutterpiTargetPlatform: flutterpiTargetPlatform,
        hostPlatform: hostPlatform,
        artifactPaths: artifactPaths,
      ),
    _ => throwToolExit('Unsupported build mode: ${buildInfo.mode}'),
  };

  final result = await buildSystem.build(target, environment);
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

  return;
}

Future<T> runInContext<T>({
  required FutureOr<T> Function() runner,
  FlutterpiTargetPlatform? targetPlatform,
  Set<FlutterpiTargetPlatform>? targetPlatforms,
  bool verbose = false,
}) async {
  Logger Function() loggerFactory = () => globals.platform.isWindows
      ? WindowsStdoutLogger(
          terminal: globals.terminal,
          stdio: globals.stdio,
          outputPreferences: globals.outputPreferences,
        )
      : StdoutLogger(
          terminal: globals.terminal,
          stdio: globals.stdio,
          outputPreferences: globals.outputPreferences,
        );

  if (verbose) {
    final oldLoggerFactory = loggerFactory;
    loggerFactory = () => VerboseLogger(oldLoggerFactory());
  }

  targetPlatforms ??= targetPlatform != null ? {targetPlatform} : null;
  targetPlatforms ??= FlutterpiTargetPlatform.values.toSet();

  Artifacts Function() artifactsGenerator;
  if (targetPlatform != null) {
    artifactsGenerator = () => FlutterpiCachedGenSnapshotArtifacts(
          parent: CachedArtifacts(
            fileSystem: globals.fs,
            cache: globals.cache,
            platform: globals.platform,
            operatingSystemUtils: globals.os,
          ),
          flutterpiTargetPlatform: targetPlatform,
          fileSystem: globals.fs,
          platform: globals.platform,
          cache: globals.cache,
          operatingSystemUtils: globals.os,
        );
  } else {
    artifactsGenerator = () => CachedArtifacts(
          fileSystem: globals.fs,
          cache: globals.cache,
          platform: globals.platform,
          operatingSystemUtils: globals.os,
        );
  }

  return context_runner.runInContext(
    runner,
    overrides: {
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      Cache: () => FlutterpiCache(
            logger: globals.logger,
            fileSystem: globals.fs,
            platform: globals.platform,
            osUtils: globals.os,
            projectFactory: globals.projectFactory,
            flutterpiPlatforms: targetPlatforms!,
          ),
      OperatingSystemUtils: () => TarXzCompatibleOsUtils(
            os: OperatingSystemUtils(
              fileSystem: globals.fs,
              logger: globals.logger,
              platform: globals.platform,
              processManager: globals.processManager,
            ),
            processUtils: ProcessUtils(
              processManager: globals.processManager,
              logger: globals.logger,
            ),
          ),
      Logger: loggerFactory,
      Artifacts: artifactsGenerator,
    },
  );
}

Future<void> exitWithHooks(int code, {required ShutdownHooks shutdownHooks}) async {
  // Run shutdown hooks before flushing logs
  await shutdownHooks.runShutdownHooks(globals.logger);

  final completer = Completer<void>();

  // Give the task / timer queue one cycle through before we hard exit.
  Timer.run(() {
    try {
      globals.printTrace('exiting with code $code');
      io.exit(code);
    } catch (error, stackTrace) {
      // ignore: avoid_catches_without_on_clauses
      completer.completeError(error, stackTrace);
    }
  });

  return completer.future;
}

Never exitWithUsage(ArgParser parser, {String? errorMessage, int exitCode = 1}) {
  if (errorMessage != null) {
    print(errorMessage);
  }

  print('');
  print('Usage:');
  print('  flutterpi-tool [options...]');
  print('');
  print(parser.usage);
  io.exit(exitCode);
}

class BuildCommand extends Command<int> {
  static const archs = ['arm', 'arm64'];

  static const cpus = ['generic', 'pi3', 'pi4'];

  BuildCommand() {
    argParser
      ..addSeparator('Runtime mode options (Defaults to debug. At most one can be specified)')
      ..addFlag('debug', negatable: false, help: 'Build for debug mode.')
      ..addFlag('profile', negatable: false, help: 'Build for profile mode.')
      ..addFlag('release', negatable: false, help: 'Build for release mode.')
      ..addFlag(
        'debug-unoptimized',
        negatable: false,
        help: 'Build for debug mode and use unoptimized engine. (For stepping through engine code)',
      )
      ..addSeparator('Build options')
      ..addFlag('tree-shake-icons',
          help: 'Tree shake icon fonts so that only glyphs used by the application remain.', defaultsTo: true)
      ..addSeparator('Target options')
      ..addOption(
        'arch',
        allowed: archs,
        defaultsTo: 'arm',
        help: 'The target architecture to build for.',
        valueHelp: 'target arch',
        allowedHelp: {
          'arm': 'Build for 32-bit ARM. (armv7-linux-gnueabihf)',
          'arm64': 'Build for 64-bit ARM. (aarch64-linux-gnu)',
        },
      )
      ..addOption(
        'cpu',
        allowed: cpus,
        defaultsTo: 'generic',
        help:
            'If specified, uses an engine tuned for the given CPU. An engine tuned for one CPU will likely not work on other CPUs.',
        valueHelp: 'target cpu',
        allowedHelp: {
          'generic':
              'Don\'t use a tuned engine. The generic engine will work on all CPUs of the specified architecture.',
          'pi3': 'Use a Raspberry Pi 3 tuned engine. (-mcpu=cortex-a53 -mtune=cortex-a53)',
          'pi4': 'Use a Raspberry Pi 4 tuned engine. (-mcpu=cortex-a72+nocrypto -mtune=cortex-a72)',
        },
      );
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Builds a flutter-pi asset bundle.';

  int exitWithUsage({int exitCode = 1, String? errorMessage, String? usage}) {
    if (errorMessage != null) {
      print(errorMessage);
    }

    if (usage != null) {
      print(usage);
    } else {
      printUsage();
    }
    return exitCode;
  }

  ({
    BuildMode buildMode,
    FlutterpiTargetPlatform targetPlatform,
    bool unoptimized,
    bool treeShakeIcons,
    bool verbose,
  }) parse() {
    final results = argResults!;

    final target = switch ((results['arch'], results['cpu'])) {
      ('arm', 'generic') => FlutterpiTargetPlatform.genericArmV7,
      ('arm', 'pi3') => FlutterpiTargetPlatform.pi3,
      ('arm', 'pi4') => FlutterpiTargetPlatform.pi4,
      ('arm64', 'generic') => FlutterpiTargetPlatform.genericAArch64,
      ('arm64', 'pi3') => FlutterpiTargetPlatform.pi3_64,
      ('arm64', 'pi4') => FlutterpiTargetPlatform.pi4_64,
      (final arch, final cpu) => throw UnsupportedError('Unsupported target arch & cpu combination: $arch, $cpu'),
    };

    final (buildMode, unoptimized) = switch ((
      debug: results['debug'],
      profile: results['profile'],
      release: results['release'],
      debugUnopt: results['debug-unoptimized']
    )) {
      // single flag was specified.
      (debug: true, profile: false, release: false, debugUnopt: false) => (BuildMode.debug, false),
      (debug: false, profile: true, release: false, debugUnopt: false) => (BuildMode.profile, false),
      (debug: false, profile: false, release: true, debugUnopt: false) => (BuildMode.release, false),
      (debug: false, profile: false, release: false, debugUnopt: true) => (BuildMode.debug, true),

      // default case if no flags were specified.
      (debug: false, profile: false, release: false, debugUnopt: false) => (BuildMode.debug, false),

      // more than a single flag has been specified.
      _ => throw UsageException(
          'At most one of `--debug`, `--profile`, `--release` or `--debug-unoptimized` can be specified.',
          usage,
        )
    };

    final treeShakeIcons = results['tree-shake-icons'] as bool;

    final verbose = globalResults!['verbose'] as bool;

    return (
      buildMode: buildMode,
      targetPlatform: target,
      unoptimized: unoptimized,
      treeShakeIcons: treeShakeIcons,
      verbose: verbose,
    );
  }

  @override
  Future<int> run() async {
    final parsed = parse();

    Cache.flutterRoot = await getFlutterRoot();

    await runInContext(
      targetPlatform: parsed.targetPlatform,
      verbose: parsed.verbose,
      runner: () async {
        try {
          // update the cached flutter-pi artifacts
          await globals.cache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
          );

          // actually build the flutter bundle
          await buildFlutterpiBundle(
            flutterpiTargetPlatform: parsed.targetPlatform,
            buildInfo: switch (parsed.buildMode) {
              BuildMode.debug => BuildInfo(
                  BuildMode.debug,
                  null,
                  trackWidgetCreation: true,
                  treeShakeIcons: parsed.treeShakeIcons,
                ),
              BuildMode.profile => BuildInfo(
                  BuildMode.profile,
                  null,
                  treeShakeIcons: parsed.treeShakeIcons,
                ),
              BuildMode.release => BuildInfo(
                  BuildMode.release,
                  null,
                  treeShakeIcons: parsed.treeShakeIcons,
                ),
              _ => throw UnsupportedError('Build mode ${parsed.buildMode} is not supported.'),
            },

            // for `--debug-unoptimized` build mode
            unoptimized: parsed.unoptimized,
          );
        } on ToolExit catch (e) {
          if (e.message != null) {
            globals.printError(e.message!);
          }

          return exitWithHooks(e.exitCode ?? 1, shutdownHooks: globals.shutdownHooks);
        }
      },
    );

    return 0;
  }
}

class PrecacheCommand extends Command<int> {
  @override
  String get name => 'precache';

  @override
  String get description => 'Precache flutter engine artifacts.';

  @override
  Future<int> run() async {
    Cache.flutterRoot = await getFlutterRoot();

    await runInContext(
      verbose: globalResults!['verbose'],
      runner: () async {
        try {
          // update the cached flutter-pi artifacts
          await globals.cache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
          );
        } on ToolExit catch (e) {
          if (e.message != null) {
            globals.printError(e.message!);
          }

          return exitWithHooks(e.exitCode ?? 1, shutdownHooks: globals.shutdownHooks);
        }
      },
    );

    return 0;
  }
}

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'flutterpi_tool',
    'A tool to make development & distribution of flutter-pi apps easier.',
    usageLineLength: 120,
  );

  runner.addCommand(BuildCommand());
  runner.addCommand(PrecacheCommand());

  runner.argParser
    ..addSeparator('Other options')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.');

  late int exitCode;
  try {
    exitCode = await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    print(e);
    exitCode = 1;
  }

  io.exitCode = exitCode;
}
