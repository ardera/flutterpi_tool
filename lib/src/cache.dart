// ignore_for_file: implementation_imports

import 'dart:io' as io;

import 'package:flutterpi_tool/src/common.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;

import 'package:flutter_tools/src/flutter_cache.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:github/github.dart' as gh;
import 'package:file/file.dart';
import 'package:meta/meta.dart';

FlutterpiCache get flutterpiCache => globals.cache as FlutterpiCache;

abstract class FlutterpiArtifact extends EngineCachedArtifact {
  FlutterpiArtifact({
    required String stampName,
    required FlutterpiCache cache,
    http.Client? httpClient,
    DevelopmentArtifact developmentArtifact = DevelopmentArtifact.universal,
  })  : _httpClient = httpClient ?? http.Client(),
        super(stampName, cache, developmentArtifact);

  final http.Client _httpClient;
  late final gh.GitHub _github = gh.GitHub(client: _httpClient);

  @override
  FlutterpiCache get cache => super.cache as FlutterpiCache;

  @override
  List<String> getPackageDirs() => const [];

  @override
  List<String> getLicenseDirs() => const [];

  List<(String, String)> getBinaryDirTuples();

  @override
  List<List<String>> getBinaryDirs() {
    return [
      for (final (path, name) in getBinaryDirTuples()) [path, name],
    ];
  }

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

    return await _github.repositories.getReleaseByTagName(cache.flutterPiEngineCi, tagName);
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

    for (final (cacheName, artifactKey) in getBinaryDirTuples()) {
      final ghAsset = ghRelease.assets!.cast<gh.ReleaseAsset?>().singleWhere(
            (asset) => asset!.name == artifactKey,
            orElse: () => null,
          );
      if (ghAsset == null) {
        throwToolExit('Flutter engine binaries with version $version and target $artifactKey are not available.');
      }

      final downloadUrl = ghAsset.browserDownloadUrl!;

      final destDir = fileSystem.directory(fileSystem.path.join(location.path, cacheName));

      await artifactUpdater.downloadZippedTarball(
        'Downloading $artifactKey...',
        Uri.parse(downloadUrl),
        destDir,
      );

      _makeFilesExecutable(destDir, operatingSystemUtils);
    }
  }

  @override
  Future<bool> checkForArtifacts(String? engineVersion) async {
    try {
      final ghRelease = await findGithubReleaseByEngineHash(version!);

      for (final (_, artifactFilename) in getBinaryDirTuples()) {
        final ghAsset = ghRelease.assets!.cast<gh.ReleaseAsset?>().singleWhere(
              (asset) => asset!.name == artifactFilename,
              orElse: () => null,
            );
        if (ghAsset == null) {
          return false;
        }
      }

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

      if (file.basename.startsWith('gen_snapshot')) {
        operatingSystemUtils.chmod(file, 'a+r,a+x');
      }
    }
  }

  bool requiredFor({
    required HostPlatform host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  });

  String toStringShort() {
    return toString();
  }
}

abstract class FlutterpiV1Artifact extends FlutterpiArtifact {
  FlutterpiV1Artifact({required super.cache, required super.stampName, super.httpClient});
}

class GenericEngineBinaries extends FlutterpiV1Artifact {
  GenericEngineBinaries({
    required super.cache,
    required Platform platform,
    super.httpClient,
  })  : _platform = platform,
        super(stampName: 'flutterpi-engine-binaries-generic');

  final Platform _platform;

  @override
  List<String> getPackageDirs() => const <String>[];

  @override
  List<(String, String)> getBinaryDirTuples() {
    if (!_platform.isLinux) {
      return [];
    }

    return [
      ('flutterpi-aarch64-generic/linux-x64', 'aarch64-generic.tar.xz'),
      ('flutterpi-armv7-generic/linux-x64', 'armv7-generic.tar.xz'),
      ('flutterpi-x64-generic/linux-x64', 'x64-generic.tar.xz'),
    ];
  }

  @override
  List<String> getLicenseDirs() {
    return <String>[];
  }

  @override
  bool requiredFor({
    required HostPlatform host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  }) {
    return host == HostPlatform.linux_x64 && targets.any((target) => target.isGeneric);
  }
}

class Pi3EngineBinaries extends FlutterpiV1Artifact {
  Pi3EngineBinaries({
    required super.cache,
    required Platform platform,
    super.httpClient,
  })  : _platform = platform,
        super(stampName: 'flutterpi-engine-binaries-pi3');

  final Platform _platform;

  @override
  List<(String, String)> getBinaryDirTuples() {
    if (!_platform.isLinux) {
      return [];
    }

    return [
      ('flutterpi-pi3/linux-x64', 'pi3.tar.xz'),
      ('flutterpi-pi3-64/linux-x64', 'pi3-64.tar.xz'),
    ];
  }

  @override
  bool requiredFor({
    required HostPlatform host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  }) {
    return host == HostPlatform.linux_x64 &&
        (targets.contains(FlutterpiTargetPlatform.pi3) || targets.contains(FlutterpiTargetPlatform.pi3_64));
  }
}

class Pi4EngineBinaries extends FlutterpiV1Artifact {
  Pi4EngineBinaries({
    required super.cache,
    required Platform platform,
    super.httpClient,
  })  : _platform = platform,
        super(stampName: 'flutterpi-engine-binaries-pi4');

  final Platform _platform;

  @override
  List<(String, String)> getBinaryDirTuples() {
    if (!_platform.isLinux) {
      return [];
    }

    return [
      ('flutterpi-pi4/linux-x64', 'pi4.tar.xz'),
      ('flutterpi-pi4-64/linux-x64', 'pi4-64.tar.xz'),
    ];
  }

  @override
  bool requiredFor({
    required HostPlatform host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  }) {
    return host == HostPlatform.linux_x64 &&
        (targets.contains(FlutterpiTargetPlatform.pi3) || targets.contains(FlutterpiTargetPlatform.pi3_64));
  }
}

class FlutterpiV2Artifact extends FlutterpiArtifact {
  static String _hostPlatformGithubName(HostPlatform host) {
    return switch (host) {
      HostPlatform.darwin_arm64 => 'macOS-ARM64',
      HostPlatform.darwin_x64 => 'macOS-X64',
      HostPlatform.linux_arm64 => 'Linux-ARM64',
      HostPlatform.linux_x64 => 'Linux-X64',
      HostPlatform.windows_x64 => 'Windows-X64',
    };
  }

  FlutterpiV2Artifact.engine(
    FlutterpiTargetPlatform this.target,
    EngineFlavor this.flavor, {
    required super.cache,
    super.httpClient,
  })  : cacheKey = 'flutterpi-engine-$target-$flavor',
        artifactFilename = 'engine-$target-$flavor.tar.xz',
        host = null,
        runtimeMode = null,
        includeDebugSymbols = null,
        super(stampName: 'flutterpi-engine-$target-$flavor');

  FlutterpiV2Artifact.engineDebugSymbols(
    FlutterpiTargetPlatform this.target,
    EngineFlavor this.flavor, {
    required super.cache,
    super.httpClient,
  })  : cacheKey = 'flutterpi-engine-dbgsyms-$target-$flavor',
        artifactFilename = 'engine-dbgsyms-$target-$flavor.tar.xz',
        host = null,
        runtimeMode = null,
        includeDebugSymbols = true,
        super(stampName: 'flutterpi-engine-dbgsyms-$target-$flavor');

  FlutterpiV2Artifact.genSnapshot(
    HostPlatform this.host,
    FlutterpiTargetPlatform this.target,
    BuildMode this.runtimeMode, {
    required super.cache,
    super.httpClient,
  })  : cacheKey = 'flutterpi-gen-snapshot-${getNameForHostPlatform(host)}-$target-$runtimeMode',
        artifactFilename = 'gen-snapshot-${_hostPlatformGithubName(host)}-$target-$runtimeMode.tar.xz',
        flavor = null,
        includeDebugSymbols = null,
        super(stampName: 'flutterpi-gen-snapshot-${getNameForHostPlatform(host)}-$target-$runtimeMode');

  FlutterpiV2Artifact.universal({
    required super.cache,
    super.httpClient,
  })  : cacheKey = 'flutterpi-universal',
        artifactFilename = 'universal.tar.xz',
        host = null,
        target = null,
        flavor = null,
        runtimeMode = null,
        includeDebugSymbols = null,
        super(stampName: 'flutterpi-universal');

  final String cacheKey;
  final String artifactFilename;
  final HostPlatform? host;
  final FlutterpiTargetPlatform? target;
  final EngineFlavor? flavor;
  final BuildMode? runtimeMode;
  final bool? includeDebugSymbols;

  @override
  bool requiredFor({
    required HostPlatform? host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  }) {
    return (this.host == null || this.host == host) &&
        (target == null || targets.contains(target)) &&
        (flavor == null || flavors.contains(flavor)) &&
        (runtimeMode == null || runtimeModes.contains(runtimeMode)) &&
        (this.includeDebugSymbols == null || this.includeDebugSymbols == includeDebugSymbols);
  }

  @override
  List<(String, String)> getBinaryDirTuples() {
    return [
      (cacheKey, artifactFilename),
    ];
  }

  @override
  String toString() {
    return 'FlutterpiV2Artifact(filename: $artifactFilename, host: $host, target: $target, flavor: $flavor, runtime mode: $runtimeMode, includes debug symbols: $includeDebugSymbols)';
  }

  @override
  String toStringShort() {
    return '\'$artifactFilename\' (v2)';
  }
}

class FlutterpiCache extends FlutterCache {
  static final _allPlatforms = FlutterpiTargetPlatform.values.toSet();
  static final _genericPlatforms = _allPlatforms.where((t) => t.isGeneric).toSet();
  static final _tunedPlatforms = _allPlatforms.where((t) => !t.isGeneric).toSet();

  static final _v2engineBuilds = {
    for (final target in _genericPlatforms)
      for (final engineFlavor in EngineFlavor.values) (target, engineFlavor),
    for (final target in _tunedPlatforms)
      for (final engineFlavor in {EngineFlavor.profile, EngineFlavor.release}) (target, engineFlavor),
  };

  static final _v2genSnapshotBuilds = {
    for (final host in {HostPlatform.linux_x64, HostPlatform.darwin_x64})
      for (final target in _genericPlatforms)
        for (final runtimeMode in {BuildMode.profile, BuildMode.release})
          (
            host,
            target,
            runtimeMode,
          ),
  };

  FlutterpiCache({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required OperatingSystemUtils osUtils,
    required super.projectFactory,
    io.HttpClient? httpClient,
  })  : _logger = logger,
        _fileSystem = fileSystem,
        _platform = platform,
        _osUtils = osUtils,
        _httpClient = httpClient ?? io.HttpClient(),
        super(
          logger: logger,
          platform: platform,
          fileSystem: fileSystem,
          osUtils: osUtils,
        ) {
    registerArtifact(GenericEngineBinaries(
      cache: this,
      platform: platform,
      httpClient: _pkgHttpHttpClient,
    ));
    registerArtifact(Pi3EngineBinaries(
      cache: this,
      platform: platform,
      httpClient: _pkgHttpHttpClient,
    ));
    registerArtifact(Pi4EngineBinaries(
      cache: this,
      platform: platform,
      httpClient: _pkgHttpHttpClient,
    ));

    for (final (target, flavor) in _v2engineBuilds) {
      registerArtifact(FlutterpiV2Artifact.engine(
        target,
        flavor,
        cache: this,
        httpClient: _pkgHttpHttpClient,
      ));
      registerArtifact(FlutterpiV2Artifact.engineDebugSymbols(
        target,
        flavor,
        cache: this,
        httpClient: _pkgHttpHttpClient,
      ));
    }

    for (final (host, target, runtimeMode) in _v2genSnapshotBuilds) {
      registerArtifact(FlutterpiV2Artifact.genSnapshot(
        host,
        target,
        runtimeMode,
        cache: this,
        httpClient: _pkgHttpHttpClient,
      ));
    }

    registerArtifact(FlutterpiV2Artifact.universal(cache: this, httpClient: _pkgHttpHttpClient));
  }

  final Logger _logger;
  final FileSystem _fileSystem;
  final Platform _platform;
  final OperatingSystemUtils _osUtils;
  final List<ArtifactSet> _artifacts = [];
  final io.HttpClient _httpClient;
  late final http.Client _pkgHttpHttpClient = http.IOClient(_httpClient);

  @override
  void registerArtifact(ArtifactSet artifactSet) {
    _artifacts.add(artifactSet);
    super.registerArtifact(artifactSet);
  }

  final flutterPiEngineCi = gh.RepositorySlug('ardera', 'flutter-ci');

  late final ArtifactUpdater _artifactUpdater = _createUpdater();

  static const flutterpiCiBaseUrl = 'https://github.com/ardera/flutter-ci/';

  FlutterpiArtifactPaths? _artifactPaths;

  FlutterpiArtifactPaths get artifactPaths {
    assert(FlutterpiV2Artifact.universal(cache: this).stampName == 'flutterpi-universal');

    if (_artifactPaths == null) {
      if (getStampFor('flutterpi-universal') != null) {
        _logger.printTrace('Artifact stamp for "flutterpi-universal" exists, using V2 artifacts.');
        _artifactPaths = FlutterpiArtifactPathsV2();
      } else {
        _logger.printTrace('Artifact stamp for "flutterpi-universal" does not exist, using V1 artifacts.');
        _artifactPaths = FlutterpiArtifactPathsV1();
      }
    }

    return _artifactPaths!;
  }

  /// This has to be lazy because it requires FLUTTER_ROOT to be initialized.
  ArtifactUpdater _createUpdater() {
    return ArtifactUpdater(
      operatingSystemUtils: _osUtils,
      logger: _logger,
      fileSystem: _fileSystem,
      tempStorage: getDownloadDir(),
      platform: _platform,
      httpClient: _httpClient,
      allowedBaseUrls: <String>[storageBaseUrl, cipdBaseUrl, flutterpiCiBaseUrl],
    );
  }

  /// Returns true if Artifact Layout v2 is available for the given engine hash.
  ///
  /// More precisely, check if the engine/$version release of the https://github.com/ardera/flutter-ci repo
  /// has a universal.tar.xz artifact.
  Future<bool> v2ArtifactsAvailable(String version) async {
    return FlutterpiV2Artifact.universal(
      cache: this,
      httpClient: _pkgHttpHttpClient,
    ).checkForArtifacts(engineRevision);
  }

  @visibleForTesting
  Set<FlutterpiV2Artifact> requiredV2Artifacts({
    HostPlatform? host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<BuildMode> runtimeModes,
    required Set<EngineFlavor> flavors,
    bool includeDebugSymbols = false,
  }) {
    return {
      for (final artifact in _artifacts)
        if (artifact is FlutterpiV2Artifact)
          if (artifact.requiredFor(
            host: host,
            targets: targets,
            flavors: flavors,
            runtimeModes: runtimeModes,
            includeDebugSymbols: includeDebugSymbols,
          ))
            artifact
    };
  }

  /// Update the cache to contain all `requiredArtifacts`.
  @override
  Future<void> updateAll(
    Set<DevelopmentArtifact> requiredArtifacts, {
    bool offline = false,
    Set<FlutterpiTargetPlatform> flutterpiPlatforms = const {
      FlutterpiTargetPlatform.genericArmV7,
      FlutterpiTargetPlatform.genericAArch64,
      FlutterpiTargetPlatform.genericX64,
    },
    Set<BuildMode> runtimeModes = const {
      BuildMode.debug,
      BuildMode.profile,
      BuildMode.release,
    },
    Set<EngineFlavor> engineFlavors = const {
      EngineFlavor.debug,
      EngineFlavor.profile,
      EngineFlavor.release,
    },
    bool includeDebugSymbols = false,
  }) async {
    final v2Available = await v2ArtifactsAvailable(engineRevision);
    _logger.printTrace(
      'flutter-pi CI v2 artifacts for engine '
      '${engineRevision.substring(0, 8)}... available: ${v2Available ? 'yes' : 'no'}',
    );

    for (final artifact in _artifacts) {
      if (artifact is FlutterpiV2Artifact && !v2Available) {
        continue;
      } else if (artifact is FlutterpiV1Artifact && v2Available) {
        continue;
      }

      final required = switch (artifact) {
        FlutterpiArtifact artifact => artifact.requiredFor(
            host: getCurrentHostPlatform(),
            targets: flutterpiPlatforms,
            flavors: engineFlavors,
            runtimeModes: runtimeModes,
            includeDebugSymbols: includeDebugSymbols,
          ),
        _ => requiredArtifacts.contains(artifact.developmentArtifact),
      };

      final short = artifact is FlutterpiArtifact ? artifact.toStringShort() : artifact.toString();

      if (!required) {
        _logger.printTrace('Artifact $short is not required, skipping update.');
        continue;
      }

      if (await artifact.isUpToDate(_fileSystem)) {
        _logger.printTrace('Artifact $short is up to date, skipping update.');
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

abstract class FlutterpiArtifactPaths {
  File getEngine({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  });

  File getGenSnapshot({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required BuildMode runtimeMode,
  });

  Source getEngineSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  });
}

class FlutterpiArtifactPathsV1 extends FlutterpiArtifactPaths {
  String getTargetDirName(FlutterpiTargetPlatform target) {
    return switch (target) {
      FlutterpiTargetPlatform.genericArmV7 => 'flutterpi-armv7-generic',
      FlutterpiTargetPlatform.genericAArch64 => 'flutterpi-aarch64-generic',
      FlutterpiTargetPlatform.genericX64 => 'flutterpi-x64-generic',
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

  String getEngineFilename(EngineFlavor flavor) {
    return 'libflutter_engine.so.${flavor.name}';
  }

  @override
  File getEngine({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return engineCacheDir
        .childDirectory(getTargetDirName(target))
        .childDirectory(getHostDirName(hostPlatform))
        .childFile(getEngineFilename(flavor));
  }

  @override
  File getGenSnapshot({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required BuildMode runtimeMode,
  }) {
    return engineCacheDir
        .childDirectory(getTargetDirName(target))
        .childDirectory(getHostDirName(hostPlatform))
        .childFile(getGenSnapshotFilename(hostPlatform, runtimeMode));
  }

  @override
  Source getEngineSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    final targetDirName = getTargetDirName(target);
    final hostDirName = getHostDirName(hostPlatform);
    final engineFileName = getEngineFilename(flavor);

    return Source.pattern('{CACHE_DIR}/artifacts/$artifactSubDir/$targetDirName/$hostDirName/$engineFileName');
  }
}

class FlutterpiArtifactPathsV2 extends FlutterpiArtifactPaths {
  FlutterpiArtifactPathsV2();

  @override
  File getEngine({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return engineCacheDir.childDirectory('flutterpi-engine-$target-$flavor').childFile('libflutter_engine.so');
  }

  File getEngineDbgsyms({
    required Directory engineCacheDir,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return engineCacheDir
        .childDirectory('flutterpi-engine-dbgsyms-$target-$flavor')
        .childFile('libflutter_engine.dbgsyms');
  }

  @override
  File getGenSnapshot({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required BuildMode runtimeMode,
  }) {
    return engineCacheDir
        .childDirectory('flutterpi-gen-snapshot-${getNameForHostPlatform(hostPlatform)}-$target-$runtimeMode')
        .childFile('gen_snapshot');
  }

  @override
  Source getEngineSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return Source.pattern(
        '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-$target-$flavor/libflutter_engine.so');
  }

  Source getEngineDbgsymsSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return Source.pattern(
        '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-dbgsyms-$target-$flavor/libflutter_engine.dbgsyms');
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

/// An implementation of [Artifacts] that provides individual overrides.
///
/// If an artifact is not provided, the lookup delegates to the parent.
class FlutterpiArtifacts implements Artifacts {
  /// Creates a new [OverrideArtifacts].
  ///
  /// [parent] must be provided.
  FlutterpiArtifacts({
    required this.parent,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required FileSystem fileSystem,
    required Platform platform,
    required Cache cache,
    required OperatingSystemUtils operatingSystemUtils,
    required FlutterpiArtifactPaths paths,
  })  : _flutterpiTargetPlatform = flutterpiTargetPlatform,
        _fileSystem = fileSystem,
        _cache = cache,
        _operatingSystemUtils = operatingSystemUtils,
        _paths = paths;

  final FileSystem _fileSystem;
  final Cache _cache;
  final OperatingSystemUtils _operatingSystemUtils;
  final FlutterpiTargetPlatform _flutterpiTargetPlatform;
  final FlutterpiArtifactPaths _paths;
  final Artifacts parent;

  @override
  LocalEngineInfo? get localEngineInfo => parent.localEngineInfo;

  String _getGenSnapshotPath(BuildMode buildMode) {
    return _paths
        .getGenSnapshot(
          engineCacheDir: _cache.getArtifactDirectory('engine'),
          hostPlatform: getCurrentHostPlatform(),
          target: _flutterpiTargetPlatform,
          runtimeMode: buildMode,
        )
        .path;
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
