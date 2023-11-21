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

FlutterpiCache get flutterpiCache => globals.cache as FlutterpiCache;

enum FlutterpiTargetPlatform {
  genericArmV7('generic-armv7'),
  genericAArch64('generic-aarch64'),
  genericX64('generic-x64'),
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
    registerArtifact(FlutterpiEngineBinariesGeneric(
      this,
      platform: platform,
    ));
    registerArtifact(FlutterpiEngineBinariesPi3(
      this,
      platform: platform,
    ));
    registerArtifact(FlutterpiEngineBinariesPi4(
      this,
      platform: platform,
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
    Set<FlutterpiTargetPlatform> flutterpiPlatforms = const {
      FlutterpiTargetPlatform.genericArmV7,
      FlutterpiTargetPlatform.genericAArch64,
      FlutterpiTargetPlatform.genericX64,
    },
  }) async {
    for (final ArtifactSet artifact in _artifacts) {
      final required = switch (artifact) {
        FlutterpiEngineCIArtifact _ => switch (artifact) {
            FlutterpiEngineBinariesGeneric _ => flutterpiPlatforms.contains(FlutterpiTargetPlatform.genericAArch64) ||
                flutterpiPlatforms.contains(FlutterpiTargetPlatform.genericArmV7) ||
                flutterpiPlatforms.contains(FlutterpiTargetPlatform.genericX64),
            FlutterpiEngineBinariesPi3 _ => flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi3) ||
                flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi3_64),
            FlutterpiEngineBinariesPi4 _ => flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi4) ||
                flutterpiPlatforms.contains(FlutterpiTargetPlatform.pi4_64),
          },
        _ => requiredArtifacts.contains(artifact.developmentArtifact),
      };

      if (!required) {
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

abstract class FlutterpiArtifactPaths {
  File getEngine({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  });

  File getGenSnapshot({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  });

  Source getEngineSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
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

  String getEngineFilename(BuildMode buildMode, {bool unoptimized = false}) {
    return switch ((buildMode, unoptimized)) {
      (BuildMode.debug, true) => 'libflutter_engine.so.debug_unopt',
      (BuildMode.debug, false) => 'libflutter_engine.so.debug',
      (BuildMode.profile, false) => 'libflutter_engine.so.profile',
      (BuildMode.release, false) => 'libflutter_engine.so.release',
      _ => throw UnsupportedError('Unsupported build mode: $buildMode'),
    };
  }

  @override
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

  @override
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

  @override
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

class FlutterpiArtifactPathsV2 extends FlutterpiArtifactPaths {
  FlutterpiTargetPlatform _getGenericFor(FlutterpiTargetPlatform platform) {
    switch (platform) {
      case FlutterpiTargetPlatform.pi3:
      case FlutterpiTargetPlatform.pi4:
        return FlutterpiTargetPlatform.genericArmV7;

      case FlutterpiTargetPlatform.pi3_64:
      case FlutterpiTargetPlatform.pi4_64:
        return FlutterpiTargetPlatform.genericAArch64;

      // Explicitly switch over the generic targets instead of using a default:
      // case here so we get an error when adding a new non-generic target.
      case FlutterpiTargetPlatform.genericArmV7:
      case FlutterpiTargetPlatform.genericAArch64:
      case FlutterpiTargetPlatform.genericX64:
        return platform;
    }
  }

  String _getHostString(HostPlatform hostPlatform) {
    return switch (hostPlatform) {
      HostPlatform.linux_x64 => 'linux-x64',
      HostPlatform.darwin_x64 => 'macos-x64',
      _ => throw UnsupportedError('Unsupported host platform: $hostPlatform'),
    };
  }

  String _getTargetString({required BuildMode buildMode, required FlutterpiTargetPlatform target}) {
    // for debug and debug_unopt, we don't have architecture-specific engines.
    if (buildMode == BuildMode.debug) {
      target = _getGenericFor(target);
    }

    return switch (target) {
      FlutterpiTargetPlatform.genericArmV7 => 'armv7-generic',
      FlutterpiTargetPlatform.genericAArch64 => 'aarch64-generic',
      FlutterpiTargetPlatform.genericX64 => 'x64-generic',
      FlutterpiTargetPlatform.pi3 => 'pi3',
      FlutterpiTargetPlatform.pi3_64 => 'pi3-64',
      FlutterpiTargetPlatform.pi4 => 'pi4',
      FlutterpiTargetPlatform.pi4_64 => 'pi4-64',
    };
  }

  String _getFlavorString({required BuildMode buildMode, required bool unoptimized}) {
    return switch ((buildMode, unoptimized)) {
      (BuildMode.debug, true) => 'debug_unopt',
      (BuildMode.debug, false) => 'debug',
      (BuildMode.profile, false) => 'profile',
      (BuildMode.release, false) => 'release',
      _ => throw ArgumentError('Unsupported build flavor: $buildMode, unoptimized: $unoptimized'),
    };
  }

  @override
  File getEngine({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    final target = _getTargetString(buildMode: buildMode, target: flutterpiTargetPlatform);
    final flavor = _getFlavorString(buildMode: buildMode, unoptimized: unoptimized);
    return engineCacheDir.childDirectory('flutterpi-engine-$target-$flavor').childFile('libflutter_engine.so');
  }

  File getEngineDbgsyms({
    required Directory engineCacheDir,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    final target = _getTargetString(buildMode: buildMode, target: flutterpiTargetPlatform);
    final flavor = _getFlavorString(buildMode: buildMode, unoptimized: unoptimized);
    return engineCacheDir
        .childDirectory('flutterpi-engine-dbgsyms-$target-$flavor')
        .childFile('libflutter_engine.dbgsyms');
  }

  @override
  File getGenSnapshot({
    required Directory engineCacheDir,
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    final host = _getHostString(hostPlatform);
    final target = _getTargetString(buildMode: buildMode, target: flutterpiTargetPlatform);
    final flavor = _getFlavorString(buildMode: buildMode, unoptimized: unoptimized);
    return engineCacheDir.childDirectory('flutterpi-gen-snapshot-$host-$target-$flavor').childFile('gen_snapshot');
  }

  @override
  Source getEngineSource({
    String artifactSubDir = 'engine',
    required HostPlatform hostPlatform,
    required FlutterpiTargetPlatform flutterpiTargetPlatform,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) {
    final target = _getTargetString(buildMode: buildMode, target: flutterpiTargetPlatform);
    final flavor = _getFlavorString(buildMode: buildMode, unoptimized: unoptimized);

    return Source.pattern(
        '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-$target-$flavor/libflutter_engine.so');
  }
}

sealed class FlutterpiEngineCIArtifact extends EngineCachedArtifact {
  FlutterpiEngineCIArtifact({
    required String stampName,
    required FlutterpiCache cache,
    DevelopmentArtifact developmentArtifact = DevelopmentArtifact.universal,
  }) : super(stampName, cache, developmentArtifact);

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

class FlutterpiEngineBinariesGeneric extends FlutterpiEngineCIArtifact {
  FlutterpiEngineBinariesGeneric(
    FlutterpiCache cache, {
    required Platform platform,
  })  : _platform = platform,
        super(
          'flutterpi-engine-binaries-generic',
          cache,
          DevelopmentArtifact.universal,
        );

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
}

class FlutterpiEngineBinariesPi3 extends FlutterpiEngineCIArtifact {
  FlutterpiEngineBinariesPi3(
    FlutterpiCache cache, {
    required Platform platform,
  })  : _platform = platform,
        super(
          'flutterpi-engine-binaries-pi3',
          cache,
          DevelopmentArtifact.universal,
        );

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
}

class FlutterpiEngineBinariesPi4 extends FlutterpiEngineCIArtifact {
  FlutterpiEngineBinariesPi4(
    FlutterpiCache cache, {
    required Platform platform,
  })  : _platform = platform,
        super(
          'flutterpi-engine-binaries-pi4',
          cache,
          DevelopmentArtifact.universal,
        );

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
}

final class FlutterpiCIArtifact {
  const FlutterpiCIArtifact.engine(
    this.name,
    FlutterpiTargetPlatform this.target,
    (BuildMode, bool unoptimized) this.engineFlavor,
  )   : hostPlatform = null,
        runtimeMode = null,
        includeDebugSymbols = null;

  const FlutterpiCIArtifact.engineDebugSymbols(
    this.name,
    FlutterpiTargetPlatform this.target,
    (BuildMode, bool unoptimized) this.engineFlavor,
  )   : hostPlatform = null,
        runtimeMode = null,
        includeDebugSymbols = true;

  const FlutterpiCIArtifact.genSnapshot(
    this.name,
    HostPlatform this.hostPlatform,
    FlutterpiTargetPlatform this.target,
    BuildMode this.runtimeMode,
  )   : engineFlavor = null,
        includeDebugSymbols = null;

  const FlutterpiCIArtifact.universal(this.name)
      : hostPlatform = null,
        target = null,
        engineFlavor = null,
        runtimeMode = null,
        includeDebugSymbols = null;

  final String name;
  final HostPlatform? hostPlatform;
  final FlutterpiTargetPlatform? target;
  final (BuildMode, bool unoptimized)? engineFlavor;
  final BuildMode? runtimeMode;
  final bool? includeDebugSymbols;
}

class FlutterpiGithubArtifactsV2 {
  static const _debugUnopt = (BuildMode.debug, true);
  static const _debug = (BuildMode.debug, false);
  static const _profile = (BuildMode.profile, false);
  static const _release = (BuildMode.release, false);

  static Set<FlutterpiCIArtifact> _generateAllArtifacts() {
    bool isGeneric(FlutterpiTargetPlatform target) {
      return switch (target) {
        FlutterpiTargetPlatform.genericArmV7 => true,
        FlutterpiTargetPlatform.genericAArch64 => true,
        FlutterpiTargetPlatform.genericX64 => true,
        FlutterpiTargetPlatform.pi3 => false,
        FlutterpiTargetPlatform.pi3_64 => false,
        FlutterpiTargetPlatform.pi4 => false,
        FlutterpiTargetPlatform.pi4_64 => false,
      };
    }

    String getTargetString(FlutterpiTargetPlatform target) {
      return switch (target) {
        FlutterpiTargetPlatform.genericArmV7 => 'armv7-generic',
        FlutterpiTargetPlatform.genericAArch64 => 'aarch64-generic',
        FlutterpiTargetPlatform.genericX64 => 'x64-generic',
        FlutterpiTargetPlatform.pi3 => 'pi3',
        FlutterpiTargetPlatform.pi3_64 => 'pi3-64',
        FlutterpiTargetPlatform.pi4 => 'pi4',
        FlutterpiTargetPlatform.pi4_64 => 'pi4-64',
      };
    }

    String getFlavorStr((BuildMode, bool) flavor) {
      return switch (flavor) {
        (BuildMode.debug, true) => 'debug_unopt',
        (BuildMode.debug, false) => 'debug',
        (BuildMode.profile, false) => 'profile',
        (BuildMode.release, false) => 'release',
        _ => throw UnsupportedError('Unsupported engine flavor: $flavor'),
      };
    }

    final allPlatforms = FlutterpiTargetPlatform.values.toSet();
    final genericPlatforms = allPlatforms.where(isGeneric).toSet();
    final specificPlatforms = allPlatforms.where((t) => !isGeneric(t)).toSet();

    final artifacts = <FlutterpiCIArtifact>{};

    final engineBuilds = {
      for (final target in genericPlatforms)
        for (final engineFlavor in {_debugUnopt, _debug, _profile, _release})
          (
            target,
            engineFlavor,
          ),
      for (final target in specificPlatforms)
        for (final engineFlavor in {_profile, _release})
          (
            target,
            engineFlavor,
          ),
    };

    final genSnapshotBuilds = {
      for (final host in {HostPlatform.linux_x64, HostPlatform.darwin_x64})
        for (final target in genericPlatforms)
          for (final (runtimeMode, _) in {_debugUnopt, _debug, _profile, _release})
            (
              host,
              target,
              runtimeMode,
            ),
    };

    for (final (target, flavor) in engineBuilds) {
      final targetStr = getTargetString(target);
      final flavorStr = getFlavorStr(flavor);

      artifacts.addAll([
        FlutterpiCIArtifact.engine('engine-$targetStr-$flavorStr.tar.xz', target, flavor),
        FlutterpiCIArtifact.engineDebugSymbols('engine-dbgsyms-$targetStr-$flavorStr.tar.xz', target, flavor),
      ]);
    }

    for (final (host, target, runtimeMode) in genSnapshotBuilds) {
      final hostStr = switch (host) {
        HostPlatform.linux_x64 => 'linux-x64',
        HostPlatform.darwin_x64 => 'macos-x64',
        _ => throw UnsupportedError('Unsupported host platform: $host'),
      };
      final targetStr = getTargetString(target);
      final runtimeModeStr = getFlavorStr((runtimeMode, false));

      artifacts.add(FlutterpiCIArtifact.genSnapshot(
        'gen-snapshot-$hostStr-$targetStr-$runtimeModeStr.tar.xz',
        host,
        target,
        runtimeMode,
      ));
    }

    artifacts.add(FlutterpiCIArtifact.universal('universal.tar.xz'));

    return artifacts;
  }

  final _artifacts = _generateAllArtifacts();

  Iterable<String> _select({
    HostPlatform? hostPlatform,
    FlutterpiTargetPlatform? target,
    (BuildMode, bool unoptimized)? engineFlavor,
    BuildMode? runtimeMode,
    bool? includeDebugSymbols,
  }) {
    return _artifacts.where((artifact) {
      return (artifact.target == target || artifact.target == null) &&
          (artifact.hostPlatform == artifact.hostPlatform || artifact.hostPlatform == null) &&
          (artifact.engineFlavor == engineFlavor || artifact.engineFlavor == null) &&
          (artifact.runtimeMode == runtimeMode || artifact.runtimeMode == null) &&
          (artifact.includeDebugSymbols == includeDebugSymbols || artifact.includeDebugSymbols == null);
    }).map((artifact) => artifact.name);
  }

  Iterable<String> getArtifactsFor({
    Set<HostPlatform> hostPlatforms = const {},
    Set<FlutterpiTargetPlatform> targets = const {},
    Set<(BuildMode, bool unoptimized)> engineFlavors = const {},
    Set<BuildMode> runtimeModes = const {},
    bool includeDebugSymbols = false,
  }) {
    return {
      for (final host in <HostPlatform?>[null].followedBy(hostPlatforms))
        for (final target in <FlutterpiTargetPlatform?>[null].followedBy(targets))
          for (final engineFlavor in <(BuildMode, bool unoptimized)?>[null].followedBy(engineFlavors))
            for (final runtimeMode in <BuildMode?>[null].followedBy(runtimeModes))
              ..._select(
                hostPlatform: host,
                target: target,
                engineFlavor: engineFlavor,
                runtimeMode: runtimeMode,
                includeDebugSymbols: includeDebugSymbols,
              ),
    };
  }
}

class FlutterpiEngine extends FlutterpiEngineCIArtifact {
  FlutterpiEngine({
    required this.target,
    required super.cache,
    bool debugUnopt = false,
  }) : super(stampName: 'flutterpi-engine-$target${debugUnopt ? '-debug-unopt' : ''}');

  final FlutterpiTargetPlatform target;

  @override
  List<(String, String)> getBinaryDirTuples() {
    final target = '${this.target}';

    return [
      ('flutterpi-engine-aarch64-generic-debug', 'engine-aarch64-generic-debug.tar.xz'),
      ('flutterpi-engine-aarch64-generic-profile', 'engine-aarch64-generic-profile.tar.xz'),
      ('flutterpi-engine-aarch64-generic-release', 'engine-aarch64-generic-release.tar.xz'),
      ('flutterpi-armv7-generic', 'armv7-generic.tar.xz'),
      ('flutterpi-x64-generic', 'x64-generic.tar.xz'),
    ];
  }
}

class FlutterpiDebugSymbols extends FlutterpiEngineCIArtifact {
  FlutterpiDebugSymbols({
    required this.target,
    required super.cache,
    bool debugUnopt = false,
  }) : super(stampName: 'flutterpi-engine-dbgsyms-$target${debugUnopt ? '-debug-unopt' : ''}');

  final FlutterpiTargetPlatform target;

  @override
  List<(String, String)> getBinaryDirTuples() {
    throw UnimplementedError();
  }
}

class FlutterpiGenSnapshot extends FlutterpiEngineCIArtifact {
  FlutterpiGenSnapshot({
    required this.target,
    required super.cache,
    required BuildMode buildMode,
    bool unoptimized = false,
  }) : super(stampName: 'flutterpi-gen-snapshot-$target-$buildMode${unoptimized ? '_unopt' : ''}');

  final FlutterpiTargetPlatform target;

  @override
  List<(String, String)> getBinaryDirTuples() {
    throw UnimplementedError();
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
    const genericX64 = FlutterpiTargetPlatform.genericX64;
    const pi3 = FlutterpiTargetPlatform.pi3;
    const pi3_64 = FlutterpiTargetPlatform.pi3_64;
    const pi4 = FlutterpiTargetPlatform.pi4;
    const pi4_64 = FlutterpiTargetPlatform.pi4_64;

    // ignore: constant_identifier_names
    const linux_x64 = HostPlatform.linux_x64;

    final subdir = switch ((_flutterpiTargetPlatform, hostPlatform)) {
      (genericArmv7, linux_x64) => const ['flutterpi-armv7-generic', 'linux-x64'],
      (genericAArch64, linux_x64) => const ['flutterpi-aarch64-generic', 'linux-x64'],
      (genericX64, linux_x64) => const ['flutterpi-x64-generic', 'linux-x64'],
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
  artifactPaths ??= FlutterpiArtifactPathsV1();

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

      // The flutter_tool computes the `.dart_tool/` subdir name from the
      // build environment hash.
      // Adding a flutterpi-target entry here forces different subdirs for
      // different target platforms.
      //
      // If we don't have this, the flutter tool will happily reuse as much as
      // it can, and it determines it can reuse the `app.so` from (for example)
      // an arm build with an arm64 build, leading to errors.
      'flutterpi-target': flutterpiTargetPlatform.shortName,
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
  static const archs = ['arm', 'arm64', 'x64'];

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
      ..addFlag(
        'tree-shake-icons',
        help: 'Tree shake icon fonts so that only glyphs used by the application remain.',
      )
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
          'x64': 'Build for x86-64. (x86_64-linux-gnu)',
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
          'pi3':
              'Use a Raspberry Pi 3 tuned engine. Compatible with arm and arm64. (-mcpu=cortex-a53 -mtune=cortex-a53)',
          'pi4':
              'Use a Raspberry Pi 4 tuned engine. Compatible with arm and arm64. (-mcpu=cortex-a72+nocrypto -mtune=cortex-a72)',
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
    bool? treeShakeIcons,
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
      ('x64', 'generic') => FlutterpiTargetPlatform.genericX64,
      (final arch, final cpu) => throw UsageException(
          'Unsupported target arch & cpu combination: architecture "$arch" is not supported for cpu "$cpu"',
          usage,
        ),
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

    final treeShakeIcons = results['tree-shake-icons'] as bool?;

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
          await flutterpiCache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
            flutterpiPlatforms: {parsed.targetPlatform},
          );

          // actually build the flutter bundle
          await buildFlutterpiBundle(
            flutterpiTargetPlatform: parsed.targetPlatform,
            buildInfo: switch (parsed.buildMode) {
              BuildMode.debug => BuildInfo(
                  BuildMode.debug,
                  null,
                  trackWidgetCreation: true,
                  treeShakeIcons: parsed.treeShakeIcons ?? BuildInfo.debug.treeShakeIcons,
                ),
              BuildMode.profile => BuildInfo(
                  BuildMode.profile,
                  null,
                  treeShakeIcons: parsed.treeShakeIcons ?? BuildInfo.profile.treeShakeIcons,
                ),
              BuildMode.release => BuildInfo(
                  BuildMode.release,
                  null,
                  treeShakeIcons: parsed.treeShakeIcons ?? BuildInfo.release.treeShakeIcons,
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
  String get description => 'Populate the flutterpi_tool\'s cache of binary artifacts.';

  @override
  Future<int> run() async {
    Cache.flutterRoot = await getFlutterRoot();

    final ghArtifacts = FlutterpiGithubArtifactsV2();

    {
      for (final target in FlutterpiTargetPlatform.values)
        ghArtifacts.getArtifactsFor(
          hostPlatform: getCurrentHostPlatform(),
          target: target,
        );
    }

    await runInContext(
      verbose: globalResults!['verbose'],
      runner: () async {
        try {
          // update the cached flutter-pi artifacts
          await flutterpiCache.updateAll(
            const {DevelopmentArtifact.universal},
            offline: false,
            flutterpiPlatforms: FlutterpiTargetPlatform.values.toSet(),
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
