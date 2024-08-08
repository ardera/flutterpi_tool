import 'dart:async';

import 'package:file/memory.dart';
import 'package:github/github.dart';
import 'package:http/testing.dart' as http;
import 'package:test/test.dart';

import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

import 'fake_github.dart';
import 'src/fake_process_manager.dart';

const githubApiResponse = '''
{
  "url": "https://api.github.com/repos/ardera/flutter-pi/releases/159500529",
  "assets_url": "https://api.github.com/repos/ardera/flutter-pi/releases/159500529/assets",
  "upload_url": "https://uploads.github.com/repos/ardera/flutter-pi/releases/159500529/assets{?name,label}",
  "html_url": "https://github.com/ardera/flutter-pi/releases/tag/release/1.0.0",
  "id": 159500529,
  "author": {
    "login": "github-actions[bot]",
    "id": 41898282,
    "node_id": "MDM6Qm90NDE4OTgyODI=",
    "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/github-actions%5Bbot%5D",
    "html_url": "https://github.com/apps/github-actions",
    "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
    "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
    "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
    "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
    "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
    "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
    "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
    "type": "Bot",
    "site_admin": false
  },
  "node_id": "RE_kwDOC1j4Fc4Jgcjx",
  "tag_name": "release/1.0.0",
  "target_commitish": "master",
  "name": "release/1.0.0",
  "draft": false,
  "prerelease": false,
  "created_at": "2024-06-08T08:44:57Z",
  "published_at": "2024-06-08T08:49:27Z",
  "assets": [
    {
      "url": "https://api.github.com/repos/ardera/flutter-pi/releases/assets/172629658",
      "id": 172629658,
      "node_id": "RA_kwDOC1j4Fc4KSh6a",
      "name": "flutterpi-aarch64-linux-gnu-debug.tar.xz",
      "label": "",
      "uploader": {
        "login": "github-actions[bot]",
        "id": 41898282,
        "node_id": "MDM6Qm90NDE4OTgyODI=",
        "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/github-actions%5Bbot%5D",
        "html_url": "https://github.com/apps/github-actions",
        "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
        "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
        "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
        "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
        "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
        "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
        "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
        "type": "Bot",
        "site_admin": false
      },
      "content_type": "application/x-xz",
      "state": "uploaded",
      "size": 314756,
      "download_count": 114,
      "created_at": "2024-06-08T08:49:27Z",
      "updated_at": "2024-06-08T08:49:27Z",
      "browser_download_url": "https://github.com/ardera/flutter-pi/releases/download/release/1.0.0/flutterpi-aarch64-linux-gnu-debug.tar.xz"
    },
    {
      "url": "https://api.github.com/repos/ardera/flutter-pi/releases/assets/172629656",
      "id": 172629656,
      "node_id": "RA_kwDOC1j4Fc4KSh6Y",
      "name": "flutterpi-aarch64-linux-gnu-release.tar.xz",
      "label": "",
      "uploader": {
        "login": "github-actions[bot]",
        "id": 41898282,
        "node_id": "MDM6Qm90NDE4OTgyODI=",
        "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/github-actions%5Bbot%5D",
        "html_url": "https://github.com/apps/github-actions",
        "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
        "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
        "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
        "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
        "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
        "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
        "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
        "type": "Bot",
        "site_admin": false
      },
      "content_type": "application/x-xz",
      "state": "uploaded",
      "size": 105720,
      "download_count": 114,
      "created_at": "2024-06-08T08:49:27Z",
      "updated_at": "2024-06-08T08:49:27Z",
      "browser_download_url": "https://github.com/ardera/flutter-pi/releases/download/release/1.0.0/flutterpi-aarch64-linux-gnu-release.tar.xz"
    },
    {
      "url": "https://api.github.com/repos/ardera/flutter-pi/releases/assets/172629659",
      "id": 172629659,
      "node_id": "RA_kwDOC1j4Fc4KSh6b",
      "name": "flutterpi-arm-linux-gnueabihf-debug.tar.xz",
      "label": "",
      "uploader": {
        "login": "github-actions[bot]",
        "id": 41898282,
        "node_id": "MDM6Qm90NDE4OTgyODI=",
        "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/github-actions%5Bbot%5D",
        "html_url": "https://github.com/apps/github-actions",
        "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
        "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
        "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
        "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
        "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
        "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
        "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
        "type": "Bot",
        "site_admin": false
      },
      "content_type": "application/x-xz",
      "state": "uploaded",
      "size": 296388,
      "download_count": 110,
      "created_at": "2024-06-08T08:49:27Z",
      "updated_at": "2024-06-08T08:49:27Z",
      "browser_download_url": "https://github.com/ardera/flutter-pi/releases/download/release/1.0.0/flutterpi-arm-linux-gnueabihf-debug.tar.xz"
    },
    {
      "url": "https://api.github.com/repos/ardera/flutter-pi/releases/assets/172629655",
      "id": 172629655,
      "node_id": "RA_kwDOC1j4Fc4KSh6X",
      "name": "flutterpi-arm-linux-gnueabihf-release.tar.xz",
      "label": "",
      "uploader": {
        "login": "github-actions[bot]",
        "id": 41898282,
        "node_id": "MDM6Qm90NDE4OTgyODI=",
        "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/github-actions%5Bbot%5D",
        "html_url": "https://github.com/apps/github-actions",
        "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
        "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
        "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
        "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
        "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
        "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
        "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
        "type": "Bot",
        "site_admin": false
      },
      "content_type": "application/x-xz",
      "state": "uploaded",
      "size": 104012,
      "download_count": 118,
      "created_at": "2024-06-08T08:49:27Z",
      "updated_at": "2024-06-08T08:49:27Z",
      "browser_download_url": "https://github.com/ardera/flutter-pi/releases/download/release/1.0.0/flutterpi-arm-linux-gnueabihf-release.tar.xz"
    },
    {
      "url": "https://api.github.com/repos/ardera/flutter-pi/releases/assets/172629657",
      "id": 172629657,
      "node_id": "RA_kwDOC1j4Fc4KSh6Z",
      "name": "flutterpi-x86_64-linux-gnu-debug.tar.xz",
      "label": "",
      "uploader": {
        "login": "github-actions[bot]",
        "id": 41898282,
        "node_id": "MDM6Qm90NDE4OTgyODI=",
        "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/github-actions%5Bbot%5D",
        "html_url": "https://github.com/apps/github-actions",
        "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
        "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
        "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
        "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
        "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
        "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
        "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
        "type": "Bot",
        "site_admin": false
      },
      "content_type": "application/x-xz",
      "state": "uploaded",
      "size": 318924,
      "download_count": 109,
      "created_at": "2024-06-08T08:49:27Z",
      "updated_at": "2024-06-08T08:49:27Z",
      "browser_download_url": "https://github.com/ardera/flutter-pi/releases/download/release/1.0.0/flutterpi-x86_64-linux-gnu-debug.tar.xz"
    },
    {
      "url": "https://api.github.com/repos/ardera/flutter-pi/releases/assets/172629660",
      "id": 172629660,
      "node_id": "RA_kwDOC1j4Fc4KSh6c",
      "name": "flutterpi-x86_64-linux-gnu-release.tar.xz",
      "label": "",
      "uploader": {
        "login": "github-actions[bot]",
        "id": 41898282,
        "node_id": "MDM6Qm90NDE4OTgyODI=",
        "avatar_url": "https://avatars.githubusercontent.com/in/15368?v=4",
        "gravatar_id": "",
        "url": "https://api.github.com/users/github-actions%5Bbot%5D",
        "html_url": "https://github.com/apps/github-actions",
        "followers_url": "https://api.github.com/users/github-actions%5Bbot%5D/followers",
        "following_url": "https://api.github.com/users/github-actions%5Bbot%5D/following{/other_user}",
        "gists_url": "https://api.github.com/users/github-actions%5Bbot%5D/gists{/gist_id}",
        "starred_url": "https://api.github.com/users/github-actions%5Bbot%5D/starred{/owner}{/repo}",
        "subscriptions_url": "https://api.github.com/users/github-actions%5Bbot%5D/subscriptions",
        "organizations_url": "https://api.github.com/users/github-actions%5Bbot%5D/orgs",
        "repos_url": "https://api.github.com/users/github-actions%5Bbot%5D/repos",
        "events_url": "https://api.github.com/users/github-actions%5Bbot%5D/events{/privacy}",
        "received_events_url": "https://api.github.com/users/github-actions%5Bbot%5D/received_events",
        "type": "Bot",
        "site_admin": false
      },
      "content_type": "application/x-xz",
      "state": "uploaded",
      "size": 119416,
      "download_count": 108,
      "created_at": "2024-06-08T08:49:27Z",
      "updated_at": "2024-06-08T08:49:27Z",
      "browser_download_url": "https://github.com/ardera/flutter-pi/releases/download/release/1.0.0/flutterpi-x86_64-linux-gnu-release.tar.xz"
    }
  ],
  "tarball_url": "https://api.github.com/repos/ardera/flutter-pi/tarball/release/1.0.0",
  "zipball_url": "https://api.github.com/repos/ardera/flutter-pi/zipball/release/1.0.0",
  "body": "Initial Github release with prebuilt artifacts.",
  "reactions": {
    "url": "https://api.github.com/repos/ardera/flutter-pi/releases/159500529/reactions",
    "total_count": 6,
    "+1": 0,
    "-1": 0,
    "laugh": 0,
    "hooray": 0,
    "confused": 0,
    "heart": 0,
    "rocket": 6,
    "eyes": 0
  }
}''';

Future<Set<String>> getArtifactKeysFor({
  FlutterpiHostPlatform? host,
  Set<FlutterpiTargetPlatform> targets = const {},
  Set<EngineFlavor> flavors = const {},
  Set<BuildMode> runtimeModes = const {},
  bool includeDebugSymbols = false,
}) async {
  final logger = BufferLogger.test();
  final fs = MemoryFileSystem.test();
  final platform = FakePlatform();
  final hooks = ShutdownHooks();

  final cache = FlutterpiCache(
    logger: logger,
    fileSystem: fs,
    platform: platform,
    osUtils: MoreOperatingSystemUtils(
      fileSystem: fs,
      logger: logger,
      platform: platform,
      processManager: FakeProcessManager.any(),
    ),
    projectFactory: FlutterProjectFactory(
      fileSystem: fs,
      logger: logger,
    ),
    hooks: hooks,
    processManager: FakeProcessManager.any(),
    github: FakeGithub(),
  );

  final result = cache
      .requiredArtifacts(
        host: host,
        targets: targets,
        runtimeModes: runtimeModes,
        flavors: flavors,
      )
      .map((e) => e.storageKey)
      .toSet();

  await hooks.runShutdownHooks(logger);

  return result;
}

void main() {
  test('universal artifacts', () async {
    final artifacts = await getArtifactKeysFor(
      flavors: {EngineFlavor.debugUnopt, EngineFlavor.release},
      runtimeModes: {BuildMode.debug, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
      ]),
    );
  });

  test('all engine artifacts', () async {
    final artifacts = await getArtifactKeysFor(
      targets: {
        FlutterpiTargetPlatform.genericAArch64,
        FlutterpiTargetPlatform.genericArmV7,
        FlutterpiTargetPlatform.genericX64,
        FlutterpiTargetPlatform.pi3,
        FlutterpiTargetPlatform.pi3_64,
        FlutterpiTargetPlatform.pi4,
        FlutterpiTargetPlatform.pi4_64,
      },
      flavors: {
        EngineFlavor.debugUnopt,
        EngineFlavor.debug,
        EngineFlavor.profile,
        EngineFlavor.release,
      },
      runtimeModes: {BuildMode.debug, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
        'engine-armv7-generic-debug_unopt.tar.xz',
        'engine-armv7-generic-debug.tar.xz',
        'engine-armv7-generic-profile.tar.xz',
        'engine-armv7-generic-release.tar.xz',
        'engine-aarch64-generic-debug_unopt.tar.xz',
        'engine-aarch64-generic-debug.tar.xz',
        'engine-aarch64-generic-profile.tar.xz',
        'engine-aarch64-generic-release.tar.xz',
        'engine-x64-generic-debug.tar.xz',
        'engine-x64-generic-debug_unopt.tar.xz',
        'engine-x64-generic-profile.tar.xz',
        'engine-x64-generic-release.tar.xz',
        'engine-pi3-profile.tar.xz',
        'engine-pi3-release.tar.xz',
        'engine-pi3-64-profile.tar.xz',
        'engine-pi3-64-release.tar.xz',
        'engine-pi4-profile.tar.xz',
        'engine-pi4-release.tar.xz',
        'engine-pi4-64-profile.tar.xz',
        'engine-pi4-64-release.tar.xz',
      ]),
    );
  });

  test('all linux-x64 gen_snapshots', () async {
    final artifacts = await getArtifactKeysFor(
      host: FlutterpiHostPlatform.linuxX64,
      targets: {
        FlutterpiTargetPlatform.genericAArch64,
        FlutterpiTargetPlatform.genericArmV7,
        FlutterpiTargetPlatform.genericX64,
        FlutterpiTargetPlatform.pi3,
        FlutterpiTargetPlatform.pi3_64,
        FlutterpiTargetPlatform.pi4,
        FlutterpiTargetPlatform.pi4_64,
      },
      runtimeModes: {BuildMode.debug, BuildMode.profile, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
        'gen-snapshot-Linux-X64-armv7-generic-profile.tar.xz',
        'gen-snapshot-Linux-X64-armv7-generic-release.tar.xz',
        'gen-snapshot-Linux-X64-aarch64-generic-profile.tar.xz',
        'gen-snapshot-Linux-X64-aarch64-generic-release.tar.xz',
        'gen-snapshot-Linux-X64-x64-generic-profile.tar.xz',
        'gen-snapshot-Linux-X64-x64-generic-release.tar.xz',
      ]),
    );
  });

  test('all macos x64 gen_snapshots', () async {
    final artifacts = await getArtifactKeysFor(
      host: FlutterpiHostPlatform.darwinX64,
      targets: {
        FlutterpiTargetPlatform.genericAArch64,
        FlutterpiTargetPlatform.genericArmV7,
        FlutterpiTargetPlatform.genericX64,
        FlutterpiTargetPlatform.pi3,
        FlutterpiTargetPlatform.pi3_64,
        FlutterpiTargetPlatform.pi4,
        FlutterpiTargetPlatform.pi4_64,
      },
      flavors: {},
      runtimeModes: {BuildMode.debug, BuildMode.profile, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
        'gen-snapshot-macOS-X64-armv7-generic-profile.tar.xz',
        'gen-snapshot-macOS-X64-armv7-generic-release.tar.xz',
        'gen-snapshot-macOS-X64-aarch64-generic-profile.tar.xz',
        'gen-snapshot-macOS-X64-aarch64-generic-release.tar.xz',
        'gen-snapshot-macOS-X64-x64-generic-profile.tar.xz',
        'gen-snapshot-macOS-X64-x64-generic-release.tar.xz',
      ]),
    );
  });

  test('specific artifact selection', () async {
    final artifacts = await getArtifactKeysFor(
      host: FlutterpiHostPlatform.linuxX64,
      targets: {
        FlutterpiTargetPlatform.genericArmV7,
        FlutterpiTargetPlatform.pi3,
      },
      flavors: {EngineFlavor.debugUnopt, EngineFlavor.release},
      runtimeModes: {BuildMode.debug, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
        'engine-armv7-generic-debug_unopt.tar.xz',
        'engine-armv7-generic-release.tar.xz',
        'engine-pi3-release.tar.xz',
        'gen-snapshot-Linux-X64-armv7-generic-release.tar.xz',
      ]),
    );
  });

  test('specific artifact selection', () async {
    final artifacts = await getArtifactKeysFor(
      host: FlutterpiHostPlatform.linuxX64,
      targets: {
        FlutterpiTargetPlatform.genericArmV7,
        FlutterpiTargetPlatform.pi3,
        FlutterpiTargetPlatform.pi4_64,
      },
      flavors: {EngineFlavor.debugUnopt, EngineFlavor.release},
      runtimeModes: {BuildMode.debug, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
        'engine-armv7-generic-debug_unopt.tar.xz',
        'engine-armv7-generic-release.tar.xz',
        'engine-pi3-release.tar.xz',
        'engine-pi4-64-release.tar.xz',
        'gen-snapshot-Linux-X64-armv7-generic-release.tar.xz',
      ]),
    );
  });

  test('specific artifact selection', () async {
    final artifacts = await getArtifactKeysFor(
      host: FlutterpiHostPlatform.linuxX64,
      targets: {
        FlutterpiTargetPlatform.genericX64,
        FlutterpiTargetPlatform.pi3,
        FlutterpiTargetPlatform.pi4_64,
      },
      flavors: {EngineFlavor.debugUnopt, EngineFlavor.release},
      runtimeModes: {BuildMode.debug, BuildMode.release},
    );

    expect(
      artifacts,
      unorderedEquals([
        'universal.tar.xz',
        'engine-x64-generic-debug_unopt.tar.xz',
        'engine-x64-generic-release.tar.xz',
        'engine-pi3-release.tar.xz',
        'engine-pi4-64-release.tar.xz',
        'gen-snapshot-Linux-X64-x64-generic-release.tar.xz',
      ]),
    );
  });

  // TODO: Engine artifacts update checking

  group('flutter-pi update checking', () {
    late BufferLogger logger;
    late MemoryFileSystem fs;
    late FakePlatform platform;
    late FakeGithub github;
    late FakeProcessManager cacheProcessManager, binariesProcessManager;
    late bool gitWasCalled;
    late bool apiWasCalled;
    late http.MockClient httpClient;
    late FlutterpiBinaries binaries;
    late Cache cache;
    late List<ArtifactSet> artifacts;

    setup({
      String? gitOutput,
      String? apiOutput,
      String? stamp,
      bool createArtifactLocation = false,
    }) {
      logger = BufferLogger.test();
      fs = MemoryFileSystem.test();
      platform = FakePlatform();
      github = FakeGithub();

      github.getLatestReleaseFn = (repo) async {
        expect(repo.fullName, 'ardera/flutter-pi');
        apiWasCalled = true;
        return Release(tagName: 'release/1.0.0');
      };

      cacheProcessManager = FakeProcessManager.list([
        FakeCommand(command: ['chmod', '755', 'cache/bin/cache']),
        FakeCommand(command: ['chmod', '755', 'cache/bin/cache/artifacts']),
      ]);

      binariesProcessManager = FakeProcessManager.list([
        FakeCommand(
          command: [
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
            'https://github.com/ardera/flutter-pi.git',
            'refs/tags/release/*',
          ],
          onRun: () => gitWasCalled = true,
          stdout: gitOutput ?? 'abcdef\trefs/tags/release/1.0.0',
        ),
      ]);

      gitWasCalled = false;

      apiWasCalled = false;
      httpClient = http.MockClient((req) async {
        neverCalled();
        throw UnimplementedError();
      });

      artifacts = [];

      cache = Cache.test(
        logger: logger,
        fileSystem: fs,
        platform: platform,
        processManager: cacheProcessManager,
        artifacts: artifacts,
      );

      binaries = FlutterpiBinaries(
        cache: cache,
        fs: fs,
        httpClient: httpClient,
        logger: logger,
        processManager: binariesProcessManager,
        github: github,
      );

      artifacts.add(binaries);

      cache.getCacheDir('').createSync(recursive: true);

      if (stamp != null) cache.setStampFor(binaries.stampName, stamp);
      if (createArtifactLocation) binaries.location.createSync(recursive: true);
    }

    test('no stamp & artifact location present', () async {
      setup();

      await expectLater(binaries.isUpToDate(fs), completion(isFalse));
      expect(gitWasCalled, isFalse);
      expect(apiWasCalled, isFalse);
    });

    test(
      'stamp present, artifact location not present',
      () async {
        setup(stamp: 'release/1.0.0');

        expect(cache.getStampFor(binaries.stampName), 'release/1.0.0');

        await expectLater(binaries.isUpToDate(fs), completion(isFalse));
        expect(gitWasCalled, isFalse);
        expect(apiWasCalled, isFalse);
      },
    );

    test('stamp and artifact location present', () async {
      setup(stamp: 'release/1.0.0', createArtifactLocation: true);

      expect(cache.getStampFor(binaries.stampName), 'release/1.0.0');

      await expectLater(binaries.isUpToDate(fs), completion(isTrue));
      expect(gitWasCalled, isTrue);
      expect(apiWasCalled, isFalse);
    });

    test('stamp & artifact location present, git has new version, API does not',
        () async {
      setup(
        gitOutput: 'abcdef\trefs/tags/release/1.1.0\n'
            'abcdeg\trefs/tags/release/1.0.0',
        stamp: 'release/1.0.0',
        createArtifactLocation: true,
      );

      expect(cache.getStampFor(binaries.stampName), 'release/1.0.0');

      await expectLater(binaries.isUpToDate(fs), completion(isTrue));
      expect(gitWasCalled, isTrue);
      expect(apiWasCalled, isTrue);
    });

    test('stamp & artifact location present, git and API have new version',
        () async {
      setup(
        gitOutput: 'abcdef\trefs/tags/release/1.0.0\n'
            'abcdeg\trefs/tags/release/0.9.0',
        stamp: 'release/0.9.0',
        createArtifactLocation: true,
      );

      expect(cache.getStampFor(binaries.stampName), 'release/0.9.0');

      await expectLater(binaries.isUpToDate(fs), completion(isFalse));
      expect(gitWasCalled, isTrue);
      expect(apiWasCalled, isTrue);
    });
  });
}
