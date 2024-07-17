import 'dart:async';

import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

import 'src/fake_process_manager.dart';

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

  final cache = GithubRepoReleasesFlutterpiCache(
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
}
