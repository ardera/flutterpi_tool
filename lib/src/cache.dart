// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:flutterpi_tool/src/authenticating_artifact_updater.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;
import 'package:meta/meta.dart';

import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;

FlutterpiCache get flutterpiCache => globals.cache as FlutterpiCache;

extension GithubReleaseFindAsset on gh.Release {
  gh.ReleaseAsset? findAsset(String name) {
    return assets!.cast<gh.ReleaseAsset?>().singleWhere(
          (asset) => asset!.name == name,
          orElse: () => null,
        );
  }
}

class ArtifactDescription {
  ArtifactDescription.target(
    FlutterpiTargetPlatform this.target,
    EngineFlavor this.flavor, {
    required this.prefix,
    required this.cacheKey,
    this.includeDebugSymbols,
  })  : host = null,
        runtimeMode = null;

  ArtifactDescription.hostTarget(
    FlutterpiHostPlatform this.host,
    FlutterpiTargetPlatform this.target,
    BuildMode this.runtimeMode, {
    required this.prefix,
    required this.cacheKey,
  })  : flavor = null,
        includeDebugSymbols = null;

  ArtifactDescription.universal({
    required this.prefix,
    required this.cacheKey,
  })  : host = null,
        target = null,
        flavor = null,
        runtimeMode = null,
        includeDebugSymbols = null;

  final String prefix;
  final String cacheKey;

  final FlutterpiHostPlatform? host;
  final FlutterpiTargetPlatform? target;
  final EngineFlavor? flavor;
  final BuildMode? runtimeMode;
  final bool? includeDebugSymbols;

  bool requiredFor({
    required FlutterpiHostPlatform? host,
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
  String toString() {
    return 'ArtifactDescription(host: $host, target: $target, flavor: $flavor, runtime mode: $runtimeMode, includes debug symbols: $includeDebugSymbols)';
  }

  String toStringShort() {
    return '\'$cacheKey\'';
  }
}

abstract class FlutterpiArtifact extends EngineCachedArtifact {
  FlutterpiArtifact(String cacheKey, {required Cache cache}) : super(cacheKey, cache, DevelopmentArtifact.universal);

  String get storageKey;

  @override
  List<List<String>> getBinaryDirs() {
    return [
      [
        stampName,
        storageKey,
      ],
    ];
  }

  @override
  List<String> getLicenseDirs() {
    return [];
  }

  @override
  List<String> getPackageDirs() {
    return [];
  }

  @visibleForTesting
  bool requiredFor({
    required FlutterpiHostPlatform? host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  });

  @protected
  void makeFilesExecutable(Directory dir, OperatingSystemUtils os) {
    final genSnapshot = dir.childFile('gen_snapshot');
    if (genSnapshot.existsSync()) {
      os.chmod(genSnapshot, '755');
    }

    final libflutterEngine = dir.childFile('libflutter_engine.so');
    if (libflutterEngine.existsSync()) {
      os.chmod(libflutterEngine, '755');
    }
  }
}

class GithubWorkflowRunArtifact extends FlutterpiArtifact {
  GithubWorkflowRunArtifact({
    required this.httpClient,
    gh.RepositorySlug? repo,
    gh.Authentication? auth,
    required this.runId,
    this.availableEngineVersion,
    required super.cache,
    required this.artifactDescription,
  })  : repo = repo ?? gh.RepositorySlug('ardera', 'flutter-ci'),
        auth = auth ?? const gh.Authentication.anonymous(),
        storageKey = _getStorageKeyForArtifact(artifactDescription),
        super(artifactDescription.cacheKey);

  @override
  final String storageKey;

  final ArtifactDescription artifactDescription;

  final http.Client httpClient;
  late final gh.GitHub github = gh.GitHub(client: httpClient, auth: auth);
  final gh.RepositorySlug repo;
  final gh.Authentication auth;
  final String runId;
  final String? availableEngineVersion;

  static String _getStorageKeyForArtifact(ArtifactDescription description) {
    return [
      description.prefix,
      if (description.host case FlutterpiHostPlatform host) host.githubName,
      if (description.target case FlutterpiTargetPlatform target) target,
      if (description.flavor case EngineFlavor flavor) flavor.name,
      if (description.runtimeMode case BuildMode runtimeMode) runtimeMode.name,
    ].join('-');
  }

  Future<Uri?> _findArtifact(String name, String version) async {
    if (availableEngineVersion != null && version != availableEngineVersion) {
      return null;
    }

    final response = await github.getJSON(
      '/repos/${repo.fullName}/actions/runs/$runId/artifacts',
      params: {'name': name},
    );

    switch (response['total_count']) {
      case 1:
        break;
      case _:
        // 0 or more than 1 artifacts found.
        return null;
    }

    switch (response['artifacts'][0]['archive_download_url']) {
      case String url:
        return Uri.tryParse(url);
      case _:
        return null;
    }
  }

  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    assert(artifactUpdater is AuthenticatingArtifactUpdater);

    final updater = artifactUpdater as AuthenticatingArtifactUpdater;

    final dir = fileSystem.directory(fileSystem.path.join(location.path, artifactDescription.cacheKey));
    final url = await _findArtifact(storageKey, version!);

    if (url == null) {
      throwToolExit('Failed to find artifact $storageKey in run $runId of repo ${repo.fullName}');
    }

    await updater.downloadZipArchive('Downloading $storageKey...', url, dir, authenticate: _authenticate);

    makeFilesExecutable(dir, operatingSystemUtils);
  }

  void _authenticate(io.HttpClientRequest request) {
    if (auth.authorizationHeaderValue() case String header) {
      request.headers.add('Authorization', header);
    }
  }

  @override
  bool requiredFor({
    required FlutterpiHostPlatform? host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  }) {
    return artifactDescription.requiredFor(
      host: host,
      targets: targets,
      flavors: flavors,
      runtimeModes: runtimeModes,
      includeDebugSymbols: includeDebugSymbols,
    );
  }

  @override
  String toString() {
    return 'GithubWorkflowRunArtifact($storageKey, repo: ${repo.fullName}, runId: $runId)';
  }
}

class GithubReleaseArtifact extends FlutterpiArtifact {
  GithubReleaseArtifact({
    required this.httpClient,
    gh.RepositorySlug? repo,
    gh.Authentication? auth,
    required super.cache,
    required this.artifactDescription,
  })  : repo = repo ?? gh.RepositorySlug('ardera', 'flutter-ci'),
        auth = auth ?? const gh.Authentication.anonymous(),
        storageKey = _getStorageKeyForArtifact(artifactDescription),
        super(artifactDescription.cacheKey);

  @override
  final String storageKey;

  final ArtifactDescription artifactDescription;

  final http.Client httpClient;
  late final gh.GitHub github = gh.GitHub(client: httpClient, auth: auth);
  final gh.RepositorySlug repo;
  final gh.Authentication auth;

  static String _getStorageKeyForArtifact(ArtifactDescription artifact) {
    final basename = [
      artifact.prefix,
      if (artifact.host != null) artifact.host!.githubName,
      if (artifact.target != null) artifact.target!,
      if (artifact.flavor != null) artifact.flavor!.name,
      if (artifact.runtimeMode != null) artifact.runtimeMode!.name,
    ].join('-');
    return '$basename.tar.xz';
  }

  final Map<String, gh.Release> _releaseCache = {};

  Future<gh.Release> _findRelease(String hash) async {
    if (_releaseCache.containsKey(hash)) {
      return _releaseCache[hash]!;
    }

    final tagName = 'engine/$hash';
    final release = await github.repositories.getReleaseByTagName(repo, tagName);

    _releaseCache[hash] = release;
    return release;
  }

  Future<gh.ReleaseAsset?> _findReleaseAsset(String name, String version) async {
    final release = await _findRelease(version);
    return release.findAsset(name);
  }

  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    assert(artifactUpdater is AuthenticatingArtifactUpdater);

    final updater = artifactUpdater as AuthenticatingArtifactUpdater;

    final dir = fileSystem.directory(fileSystem.path.join(location.path, artifactDescription.cacheKey));

    final asset = await _findReleaseAsset(storageKey, version!);

    final url = switch (asset?.browserDownloadUrl) {
      String url => Uri.tryParse(url),
      _ => null,
    };
    if (url == null) {
      throwToolExit('Failed to find artifact $storageKey in release $version');
    }

    await updater.downloadArchive(
      'Downloading $storageKey...',
      url,
      dir,
      authenticate: _authenticate,
      archiveType: ArchiveType.tarXz,
    );

    makeFilesExecutable(dir, operatingSystemUtils);
  }

  void _authenticate(io.HttpClientRequest request) {
    if (auth.authorizationHeaderValue() case String header) {
      request.headers.add('Authorization', header);
      print('Authorization header added: $header');
    }
  }

  @override
  bool requiredFor({
    required FlutterpiHostPlatform? host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<EngineFlavor> flavors,
    required Set<BuildMode> runtimeModes,
    required bool includeDebugSymbols,
  }) {
    return artifactDescription.requiredFor(
      host: host,
      targets: targets,
      flavors: flavors,
      runtimeModes: runtimeModes,
      includeDebugSymbols: includeDebugSymbols,
    );
  }

  @override
  String toString() {
    return 'GithubReleaseArtifact($storageKey, repo: ${repo.fullName})';
  }
}

abstract class FlutterpiCache extends FlutterCache {
  FlutterpiCache({
    required this.logger,
    required this.fileSystem,
    required this.platform,
    required this.osUtils,
    required super.projectFactory,
    required ShutdownHooks hooks,
    io.HttpClient? httpClient,
  })  : httpClient = httpClient ?? io.HttpClient(),
        super(
          logger: logger,
          platform: platform,
          fileSystem: fileSystem,
          osUtils: osUtils,
        ) {
    hooks.addShutdownHook(() {
      // this will close the inner dart:io http client.
      pkgHttpHttpClient.close();
    });
  }

  @protected
  final Logger logger;
  @protected
  final FileSystem fileSystem;
  @protected
  final Platform platform;
  @protected
  final MoreOperatingSystemUtils osUtils;
  @protected
  final io.HttpClient httpClient;
  @protected
  late final http.Client pkgHttpHttpClient = http.IOClient(httpClient);

  @protected
  final List<ArtifactSet> artifacts = [];

  @override
  void registerArtifact(ArtifactSet artifactSet) {
    super.registerArtifact(artifactSet);
    artifacts.add(artifactSet);
  }

  @protected
  List<ArtifactDescription> generateDescriptions() {
    final hosts = {
      FlutterpiHostPlatform.darwinX64,
      FlutterpiHostPlatform.linuxARM,
      FlutterpiHostPlatform.linuxARM64,
      FlutterpiHostPlatform.linuxX64,
      FlutterpiHostPlatform.windowsX64,
    };

    final targets = FlutterpiTargetPlatform.values;
    final flavors = EngineFlavor.values;
    final aotRuntimeModes = [
      BuildMode.profile,
      BuildMode.release,
    ];

    final descriptions = <ArtifactDescription>[];

    for (final target in targets) {
      for (final flavor in flavors) {
        if (flavor.buildMode == BuildMode.debug && !target.isGeneric) {
          // We don't enable CPU-specific optimizations for debug builds.
          continue;
        }

        descriptions.add(ArtifactDescription.target(
          target,
          flavor,
          prefix: 'engine',
          cacheKey: 'flutterpi-engine-$target-$flavor',
        ));

        descriptions.add(ArtifactDescription.target(
          target,
          flavor,
          prefix: 'engine-dbgsyms',
          cacheKey: 'flutterpi-engine-dbgsyms-$target-$flavor',
          includeDebugSymbols: true,
        ));
      }
    }

    for (final host in hosts) {
      for (final target in targets) {
        if (host.bitness == Bitness.b32 && target.bitness != Bitness.b32) {
          // 32-bit machines can only build for other 32-bit targets.
          continue;
        }

        if (!target.isGeneric) {
          // gen_snapshot can only target generic CPUs,
          // so we can't build it for any of the specific targets.
          continue;
        }

        for (final runtimeMode in aotRuntimeModes) {
          descriptions.add(ArtifactDescription.hostTarget(
            host,
            target,
            runtimeMode,
            prefix: 'gen-snapshot',
            cacheKey: 'flutterpi-gen-snapshot-$host-$target-$runtimeMode',
          ));
        }
      }
    }

    descriptions.add(ArtifactDescription.universal(
      prefix: 'universal',
      cacheKey: 'flutterpi-universal',
    ));

    return descriptions;
  }

  late final ArtifactUpdater _updater = createUpdater();

  FlutterpiArtifactPaths artifactPaths = FlutterpiArtifactPathsV2();

  List<String> get allowedBaseUrls => [
        cipdBaseUrl,
        storageBaseUrl,
      ];

  /// This has to be lazy because it requires FLUTTER_ROOT to be initialized.
  @protected
  ArtifactUpdater createUpdater() {
    return AuthenticatingArtifactUpdater(
      operatingSystemUtils: osUtils,
      logger: logger,
      fileSystem: fileSystem,
      tempStorage: getDownloadDir(),
      httpClient: httpClient,
      platform: platform,
      allowedBaseUrls: allowedBaseUrls,
    );
  }

  @visibleForTesting
  Set<FlutterpiArtifact> requiredArtifacts({
    FlutterpiHostPlatform? host,
    required Set<FlutterpiTargetPlatform> targets,
    required Set<BuildMode> runtimeModes,
    required Set<EngineFlavor> flavors,
    bool includeDebugSymbols = false,
  }) {
    return {
      for (final artifact in artifacts)
        if (artifact is FlutterpiArtifact)
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

  @override
  Future<void> updateAll(
    Set<DevelopmentArtifact> requiredArtifacts, {
    bool offline = false,
    @required FlutterpiHostPlatform? host,
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
    host ??= osUtils.fpiHostPlatform;

    for (final artifact in artifacts) {
      final required = switch (artifact) {
        FlutterpiArtifact artifact => artifact.requiredFor(
            host: host,
            targets: flutterpiPlatforms,
            flavors: engineFlavors,
            runtimeModes: runtimeModes,
            includeDebugSymbols: includeDebugSymbols,
          ),
        _ => requiredArtifacts.contains(artifact.developmentArtifact),
      };

      final short = artifact.toString();

      if (!required) {
        logger.printTrace('Artifact $short is not required, skipping update.');
        continue;
      }

      if (await artifact.isUpToDate(fileSystem)) {
        logger.printTrace('Artifact $short is up to date, skipping update.');
        continue;
      }

      await artifact.update(
        _updater,
        logger,
        fileSystem,
        osUtils,
        offline: offline,
      );
    }
  }
}

class GithubRepoReleasesFlutterpiCache extends FlutterpiCache {
  GithubRepoReleasesFlutterpiCache({
    required super.logger,
    required super.fileSystem,
    required super.platform,
    required super.osUtils,
    required super.projectFactory,
    required super.hooks,
    super.httpClient,
    gh.RepositorySlug? repo,
    gh.Authentication? auth,
  }) : repo = repo ?? gh.RepositorySlug('ardera', 'flutter-ci') {
    for (final description in generateDescriptions()) {
      registerArtifact(GithubReleaseArtifact(
        httpClient: pkgHttpHttpClient,
        repo: repo,
        auth: auth,
        cache: this,
        artifactDescription: description,
      ));
    }
  }

  final gh.RepositorySlug repo;

  @override
  List<String> get allowedBaseUrls => [
        ...super.allowedBaseUrls,
        'https://github.com/${repo.fullName}/releases/download',
      ];
}

class GithubWorkflowRunFlutterpiCache extends FlutterpiCache {
  GithubWorkflowRunFlutterpiCache({
    required super.logger,
    required super.fileSystem,
    required super.platform,
    required super.osUtils,
    required super.projectFactory,
    required super.hooks,
    gh.RepositorySlug? repo,
    gh.Authentication? auth,
    required String runId,
    String? availableEngineVersion,
    super.httpClient,
  }) : repo = repo ?? gh.RepositorySlug('ardera', 'flutter-ci') {
    for (final artifact in generateDescriptions()) {
      registerArtifact(GithubWorkflowRunArtifact(
        httpClient: pkgHttpHttpClient,
        repo: repo,
        auth: auth,
        runId: runId,
        availableEngineVersion: availableEngineVersion,
        cache: this,
        artifactDescription: artifact,
      ));
    }
  }

  final gh.RepositorySlug repo;

  @override
  List<String> get allowedBaseUrls => [
        ...super.allowedBaseUrls,
        'https://api.github.com/repos/${repo.fullName}/actions/artifacts/',
      ];
}

abstract class FlutterpiArtifactPaths {
  File getEngine({
    required Directory engineCacheDir,
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  });

  File getGenSnapshot({
    required Directory engineCacheDir,
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required BuildMode runtimeMode,
  });

  Source getEngineSource({
    String artifactSubDir = 'engine',
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  });
}

class FlutterpiArtifactPathsV2 extends FlutterpiArtifactPaths {
  FlutterpiArtifactPathsV2();

  @override
  File getEngine({
    required Directory engineCacheDir,
    required FlutterpiHostPlatform hostPlatform,
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
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required BuildMode runtimeMode,
  }) {
    return engineCacheDir
        .childDirectory('flutterpi-gen-snapshot-$hostPlatform-$target-$runtimeMode')
        .childFile('gen_snapshot');
  }

  @override
  Source getEngineSource({
    String artifactSubDir = 'engine',
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return Source.pattern(
        '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-$target-$flavor/libflutter_engine.so');
  }

  Source getEngineDbgsymsSource({
    String artifactSubDir = 'engine',
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return Source.pattern(
        '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-dbgsyms-$target-$flavor/libflutter_engine.dbgsyms');
  }
}

/// An implementation of [Artifacts] that allows overriding the gen_snapshot
/// executable.
///
/// If an artifact is not provided, the lookup delegates to the parent.
class OverrideGenSnapshotArtifacts implements Artifacts {
  /// Creates a new [OverrideArtifacts].
  ///
  /// [parent] must be provided.
  OverrideGenSnapshotArtifacts({
    required this.parent,
    required this.genSnapshotPathProfile,
    required this.genSnapshotPathRelease,
  });

  factory OverrideGenSnapshotArtifacts.fromArtifactPaths({
    required Artifacts parent,
    required Directory engineCacheDir,
    required FlutterpiHostPlatform host,
    required FlutterpiTargetPlatform target,
    required FlutterpiArtifactPaths artifactPaths,
  }) {
    return OverrideGenSnapshotArtifacts(
      parent: parent,
      genSnapshotPathProfile: artifactPaths
          .getGenSnapshot(
            engineCacheDir: engineCacheDir,
            hostPlatform: host,
            target: target,
            runtimeMode: BuildMode.profile,
          )
          .path,
      genSnapshotPathRelease: artifactPaths
          .getGenSnapshot(
            engineCacheDir: engineCacheDir,
            hostPlatform: host,
            target: target,
            runtimeMode: BuildMode.release,
          )
          .path,
    );
  }
  final Artifacts parent;
  final String genSnapshotPathProfile;
  final String genSnapshotPathRelease;

  @override
  LocalEngineInfo? get localEngineInfo => parent.localEngineInfo;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return switch ((artifact, mode)) {
      (Artifact.genSnapshot, BuildMode.profile) => genSnapshotPathProfile,
      (Artifact.genSnapshot, BuildMode.release) => genSnapshotPathRelease,
      _ => parent.getArtifactPath(
          artifact,
          platform: platform,
          mode: mode,
          environmentType: environmentType,
        ),
    };
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
