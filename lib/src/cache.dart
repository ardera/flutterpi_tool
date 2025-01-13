// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:flutterpi_tool/src/authenticating_artifact_updater.dart';
import 'package:flutterpi_tool/src/github.dart';
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
import 'package:process/process.dart';

FlutterpiCache get flutterpiCache => globals.cache as FlutterpiCache;

extension GithubReleaseFindAsset on gh.Release {
  gh.ReleaseAsset? findAsset(String name) {
    return assets!.cast<gh.ReleaseAsset?>().singleWhere(
          (asset) => asset!.name == name,
          orElse: () => null,
        );
  }
}

class EngineArtifactDescription {
  EngineArtifactDescription.target(
    FlutterpiTargetPlatform this.target,
    EngineFlavor this.flavor, {
    required this.prefix,
    required this.cacheKey,
    this.includeDebugSymbols,
  })  : host = null,
        runtimeMode = null;

  EngineArtifactDescription.hostTarget(
    FlutterpiHostPlatform this.host,
    FlutterpiTargetPlatform this.target,
    BuildMode this.runtimeMode, {
    required this.prefix,
    required this.cacheKey,
  })  : flavor = null,
        includeDebugSymbols = null;

  EngineArtifactDescription.universal({
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
        (this.includeDebugSymbols == null ||
            this.includeDebugSymbols == includeDebugSymbols);
  }

  @override
  String toString() {
    return 'ArtifactDescription(host: $host, target: $target, flavor: $flavor, runtime mode: $runtimeMode, includes debug symbols: $includeDebugSymbols)';
  }

  String toStringShort() {
    return '\'$cacheKey\'';
  }
}

class FlutterpiBinaries extends ArtifactSet {
  FlutterpiBinaries({
    required this.cache,
    required this.fs,
    required this.httpClient,
    required this.logger,
    required this.processManager,
    required this.github,
  }) : super(DevelopmentArtifact.universal);

  final Cache cache;
  final FileSystem fs;
  final http.Client httpClient;
  final Logger logger;
  final ProcessManager processManager;
  final gh.RepositorySlug repo = gh.RepositorySlug('ardera', 'flutter-pi');
  final MyGithub github;

  Future<String?> _getLatestReleaseTag() async {
    final allReleases = await processManager.run([
      'git',
      '-c',
      'gc.autoDetach=false',
      '-c',
      'core.pager=cat',
      '-c',
      'safe.bareRepository=all',
      'ls-remote',
      '--tags',
      '--sort=-v:refname:lstrip=3',
      'https://github.com/${repo.fullName}.git',
      'refs/tags/release/*',
    ]);

    final lines = const LineSplitter().convert(allReleases.stdout as String);
    for (final line in lines) {
      const prefix = 'refs/tags/release/';

      String tag;
      try {
        [_, tag] = line.split('\t');
      } on StateError {
        continue;
      }

      if (!tag.startsWith(prefix)) {
        logger.printTrace(
          'Encountered non-release tag in `git ls-remote` output: $tag',
        );
        continue;
      }

      // remove the refs/tags/release/ prefix (and add release/ again)
      tag = 'release/${tag.substring(prefix.length)}';

      // we sorted the output in the git ls-remote invocation, so the first
      // valid release tag is the latest version.
      return tag;
    }

    return null;
  }

  Future<gh.Release> _getLatestGitHubRelease() async {
    return await github.getLatestRelease(repo);
  }

  Future<String> _getLatestVersion() async {
    final release = await _getLatestGitHubRelease();
    return switch (release.tagName) {
      String tagName => tagName,
      null => throw gh.GitHubError(
          github.github,
          'Failed to find latest release in $repo.',
        ),
    };
  }

  Future<bool> _isLatestVersion(String version) async {
    final latestReleaseTag = await _getLatestReleaseTag();
    if (latestReleaseTag != version) {
      logger.printTrace(
        'The latest flutter-pi release tag is $latestReleaseTag, but the '
        'current version is $version, so there might be a new GitHub release. '
        'Checking with GitHub API...',
      );

      final latestRelease = await _getLatestVersion();
      if (latestRelease != version) {
        logger.printTrace(
          'There is a new flutter-pi release available: $latestRelease. '
          'Current version: $version',
        );
        return false;
      }
    }

    return true;
  }

  @override
  Future<bool> isUpToDate(FileSystem fileSystem, {bool offline = false}) async {
    if (!location.existsSync()) {
      return false;
    }

    if (!offline) {
      try {
        final version = cache.getStampFor(stampName);
        if (version == null || !await _isLatestVersion(version)) {
          return false;
        }
      } on gh.GitHubError catch (e) {
        logger.printWarning(
          'Failed to check for flutter-pi updates: ${e.message}',
        );
        return true;
      } on io.ProcessException catch (e) {
        logger.printWarning(
          'Failed to run git to check for flutter-pi updates: ${e.message}',
        );
        return true;
      }
    }

    return true;
  }

  @override
  Map<String, String> get environment => <String, String>{};

  @override
  String get name => 'flutter-pi';

  @override
  String get stampName => 'flutter-pi';

  Directory get location => cache.getArtifactDirectory(name);

  @override
  Future<void> update(
    covariant AuthenticatingArtifactUpdater artifactUpdater,
    Logger logger,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils, {
    bool offline = false,
  }) async {
    if (offline) {
      throwToolExit('Cannot download flutter-pi binaries in offline mode.');
    }

    if (!location.existsSync()) {
      try {
        location.createSync(recursive: true);
      } on FileSystemException catch (err) {
        logger.printError(err.toString());
        throwToolExit(
            'Failed to create directory for flutter cache at ${location.path}. '
            'Flutter may be missing permissions in its cache directory.');
      }
    }

    final release = await _getLatestGitHubRelease();

    final artifacts = [
      for (final triple in [
        'aarch64-linux-gnu',
        'arm-linux-gnueabihf',
        'x86_64-linux-gnu',
      ])
        for (final type in ['release', 'debug'])
          (
            'flutterpi-$triple-$type.tar.xz',
            [triple, type],
          ),
    ];

    for (final (assetName, subdirs) in artifacts) {
      final asset = release.findAsset(assetName);

      final url = Uri.parse(
        switch (asset?.browserDownloadUrl) {
          String url => url,
          null => throwToolExit(
              'Failed to find asset "$assetName" in release "${release.tagName}" of repo ${repo.fullName}.',
            ),
        },
      );

      final location = this
          .location
          .fileSystem
          .directory(path.joinAll([this.location.path, ...subdirs]));

      await artifactUpdater.downloadArchive(
        'Downloading $assetName...',
        url,
        location,
        archiveType: ArchiveType.tarXz,
      );
    }

    try {
      cache.setStampFor(stampName, release.tagName!);
    } on FileSystemException catch (err) {
      logger.printWarning(
        'The new artifact "$name" was downloaded, but Flutter failed to update '
        'its stamp file, receiving the error "$err". '
        'Flutter can continue, but the artifact may be re-downloaded on '
        'subsequent invocations until the problem is resolved.',
      );
    }

    artifactUpdater.removeDownloadedFiles();
  }
}

abstract class FlutterpiArtifact extends EngineCachedArtifact {
  FlutterpiArtifact(String cacheKey, {required Cache cache})
      : super(cacheKey, cache, DevelopmentArtifact.universal);

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
    required this.myGithub,
    gh.RepositorySlug? repo,
    required this.runId,
    this.availableEngineVersion,
    required super.cache,
    required this.artifactDescription,
  })  : repo = repo ?? gh.RepositorySlug('ardera', 'flutter-ci'),
        storageKey = _getStorageKeyForArtifact(artifactDescription),
        super(artifactDescription.cacheKey);

  @override
  final String storageKey;

  final EngineArtifactDescription artifactDescription;

  final MyGithub myGithub;
  final gh.RepositorySlug repo;
  final String runId;
  final String? availableEngineVersion;

  static String _getStorageKeyForArtifact(
    EngineArtifactDescription description,
  ) {
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

    final artifact = await myGithub.getWorkflowRunArtifact(
      name,
      repo: repo,
      runId: int.parse(runId),
    );

    return artifact?.archiveDownloadUrl;
  }

  @override
  Future<void> updateInner(
    ArtifactUpdater artifactUpdater,
    FileSystem fileSystem,
    OperatingSystemUtils operatingSystemUtils,
  ) async {
    assert(artifactUpdater is AuthenticatingArtifactUpdater);

    final updater = artifactUpdater as AuthenticatingArtifactUpdater;

    final dir = fileSystem.directory(
      fileSystem.path.join(location.path, artifactDescription.cacheKey),
    );
    final url = await _findArtifact(storageKey, version!);

    if (url == null) {
      throwToolExit(
        'Failed to find artifact $storageKey in run $runId of repo ${repo.fullName}',
      );
    }

    await updater.downloadZipArchive(
      'Downloading $storageKey...',
      url,
      dir,
      authenticate: myGithub.authenticate,
    );

    makeFilesExecutable(dir, operatingSystemUtils);
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
    gh.RepositorySlug? repo,
    required super.cache,
    required this.github,
    required this.artifactDescription,
  })  : repo = repo ?? gh.RepositorySlug('ardera', 'flutter-ci'),
        storageKey = getStorageKeyForArtifact(artifactDescription),
        super(artifactDescription.cacheKey);

  @override
  final String storageKey;

  final EngineArtifactDescription artifactDescription;

  final MyGithub github;
  final gh.RepositorySlug repo;

  @visibleForTesting
  static String getStorageKeyForArtifact(EngineArtifactDescription artifact) {
    final basename = [
      artifact.prefix,
      if (artifact.host != null) artifact.host!.githubName,
      if (artifact.target != null) artifact.target!,
      if (artifact.flavor != null) artifact.flavor!.name,
      if (artifact.runtimeMode != null) artifact.runtimeMode!.name,
    ].join('-');
    return '$basename.tar.xz';
  }

  @visibleForTesting
  String tagNameFromEngineHash(String hash) => 'engine/$hash';

  Future<gh.Release> _findRelease(String hash) async {
    final tagName = tagNameFromEngineHash(hash);

    final release = await github.getReleaseByTagName(tagName, repo: repo);

    return release;
  }

  Future<gh.ReleaseAsset?> _findReleaseAsset(
    String name,
    String version,
  ) async {
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

    final dir = fileSystem.directory(
      fileSystem.path.join(location.path, artifactDescription.cacheKey),
    );

    final gh.ReleaseAsset? asset;

    try {
      asset = await _findReleaseAsset(storageKey, version!);
    } on gh.ReleaseNotFound catch (_) {
      throwToolExit('Artifacts for engine $version are not yet available.');
    }

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
      authenticate: github.authenticate,
      archiveType: ArchiveType.tarXz,
    );

    makeFilesExecutable(dir, operatingSystemUtils);
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

class FlutterpiCache extends FlutterCache {
  @protected
  FlutterpiCache.withoutEngineArtifacts({
    required this.logger,
    required this.fileSystem,
    required this.platform,
    required this.osUtils,
    required super.projectFactory,
    required ProcessManager processManager,
    required ShutdownHooks hooks,
    required MyGithub github,
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

    registerArtifact(
      FlutterpiBinaries(
        cache: this,
        fs: fileSystem,
        httpClient: pkgHttpHttpClient,
        logger: logger,
        processManager: processManager,
        github: github,
      ),
    );
  }

  factory FlutterpiCache({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required MoreOperatingSystemUtils osUtils,
    required FlutterProjectFactory projectFactory,
    required ProcessManager processManager,
    required ShutdownHooks hooks,
    required MyGithub github,
    gh.RepositorySlug? repo,
  }) {
    repo ??= gh.RepositorySlug('ardera', 'flutter-ci');

    final cache = FlutterpiCache.withoutEngineArtifacts(
      logger: logger,
      fileSystem: fileSystem,
      platform: platform,
      osUtils: osUtils,
      projectFactory: projectFactory,
      hooks: hooks,
      processManager: processManager,
      github: github,
    );

    for (final description in generateDescriptions()) {
      cache.registerArtifact(
        GithubReleaseArtifact(
          cache: cache,
          artifactDescription: description,
          github: github,
          repo: repo,
        ),
      );
    }

    return cache;
  }

  factory FlutterpiCache.fromWorkflow({
    required Logger logger,
    required FileSystem fileSystem,
    required Platform platform,
    required MoreOperatingSystemUtils osUtils,
    required FlutterProjectFactory projectFactory,
    required ProcessManager processManager,
    required ShutdownHooks hooks,
    required MyGithub github,
    gh.RepositorySlug? repo,
    required String runId,
    String? availableEngineVersion,
  }) {
    repo ??= gh.RepositorySlug('ardera', 'flutter-ci');

    final cache = FlutterpiCache.withoutEngineArtifacts(
      logger: logger,
      fileSystem: fileSystem,
      platform: platform,
      osUtils: osUtils,
      projectFactory: projectFactory,
      processManager: processManager,
      hooks: hooks,
      github: github,
    );

    for (final artifact in generateDescriptions()) {
      cache.registerArtifact(
        GithubWorkflowRunArtifact(
          myGithub: github,
          repo: repo,
          runId: runId,
          availableEngineVersion: availableEngineVersion,
          cache: cache,
          artifactDescription: artifact,
        ),
      );
    }

    return cache;
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
  static List<EngineArtifactDescription> generateDescriptions() {
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

    final descriptions = <EngineArtifactDescription>[];

    for (final target in targets) {
      for (final flavor in flavors) {
        if (flavor.buildMode == BuildMode.debug && !target.isGeneric) {
          // We don't enable CPU-specific optimizations for debug builds.
          continue;
        }

        descriptions.add(
          EngineArtifactDescription.target(
            target,
            flavor,
            prefix: 'engine',
            cacheKey: 'flutterpi-engine-$target-$flavor',
          ),
        );

        descriptions.add(
          EngineArtifactDescription.target(
            target,
            flavor,
            prefix: 'engine-dbgsyms',
            cacheKey: 'flutterpi-engine-dbgsyms-$target-$flavor',
            includeDebugSymbols: true,
          ),
        );
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
          descriptions.add(
            EngineArtifactDescription.hostTarget(
              host,
              target,
              runtimeMode,
              prefix: 'gen-snapshot',
              cacheKey: 'flutterpi-gen-snapshot-$host-$target-$runtimeMode',
            ),
          );
        }
      }
    }

    descriptions.add(
      EngineArtifactDescription.universal(
        prefix: 'universal',
        cacheKey: 'flutterpi-universal',
      ),
    );

    return descriptions;
  }

  late final ArtifactUpdater _updater = createUpdater();

  FlutterpiArtifactPaths artifactPaths = FlutterpiArtifactPathsV2();

  List<String> get allowedBaseUrls => [
        cipdBaseUrl,
        storageBaseUrl,
        'https://github.com/ardera/flutter-pi/',
        'https://github.com/ardera/flutter-ci/',
        'https://api.github.com/repos/ardera/flutter-pi/',
        'https://api.github.com/repos/ardera/flutter-ci/',
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
            artifact,
    };
  }

  @override
  Future<void> updateAll(
    Set<DevelopmentArtifact> requiredArtifacts, {
    bool offline = false,
    @required FlutterpiHostPlatform? host,
    Set<FlutterpiTargetPlatform> flutterpiPlatforms = const {},
    Set<BuildMode> runtimeModes = const {},
    Set<EngineFlavor> engineFlavors = const {},
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
    return engineCacheDir
        .childDirectory('flutterpi-engine-$target-$flavor')
        .childFile('libflutter_engine.so');
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
        .childDirectory(
          'flutterpi-gen-snapshot-$hostPlatform-$target-$runtimeMode',
        )
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
      '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-$target-$flavor/libflutter_engine.so',
    );
  }

  Source getEngineDbgsymsSource({
    String artifactSubDir = 'engine',
    required FlutterpiHostPlatform hostPlatform,
    required FlutterpiTargetPlatform target,
    required EngineFlavor flavor,
  }) {
    return Source.pattern(
      '{CACHE_DIR}/artifacts/$artifactSubDir/flutterpi-engine-dbgsyms-$target-$flavor/libflutter_engine.dbgsyms',
    );
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
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) =>
      parent.getEngineType(platform, mode);

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

  final flutterToolsPath =
      pkgconfig.resolve(Uri.parse('package:flutter_tools/'))!.toFilePath();

  const dirname = path.dirname;

  return dirname(dirname(dirname(flutterToolsPath)));
}
