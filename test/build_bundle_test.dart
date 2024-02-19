import 'dart:async';

import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/context_runner.dart' as context_runner;
import 'package:flutterpi_tool/src/build_bundle.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/flutter_tool.dart' as fltool;
import 'package:path/path.dart' as pathlib;

import 'package:test/test.dart';

import 'src/fake_process_manager.dart';

class HasPathMatcher extends CustomMatcher {
  HasPathMatcher(Object? valueOrMatcher) : super('File with path', 'path', valueOrMatcher);

  @override
  Object? featureValueOf(actual) {
    final path = (actual as File).path;
    return pathlib.canonicalize(pathlib.join('/', path));
  }
}

Matcher hasPath(Object? matcher) => HasPathMatcher(matcher);

class MockCommandRunner extends FlutterpiToolCommandRunner {}

class MockBuildCommand extends BuildCommand {
  FutureOr<void> Function()? runFunction;

  @override
  ArgResults? argResults;

  @override
  ArgResults? globalResults;

  @override
  Future<void> run() async {
    return await runFunction!.call();
  }
}

Future<void> testBuildCommand(
  Iterable<String> args, {
  required FutureOr<void> Function(BuildCommand command) test,
  Logger? logger,
  FileSystem? fileSystem,
}) async {
  logger ??= BufferLogger.test();
  fileSystem ??= MemoryFileSystem.test();

  final buildCommand = MockBuildCommand()..runFunction = () async {};
  buildCommand.argResults = buildCommand.argParser.parse(args);

  final commandRunner = MockCommandRunner()..addCommand(buildCommand);
  buildCommand.globalResults = commandRunner.parse([]);

  await context_runner.runInContext(
    () async {
      await test(buildCommand);
    },
    overrides: {
      Logger: () => logger,
      FileSystem: () => fileSystem,
    },
  );
}

void main() {
  test('simple dart defines work', () async {
    late final BuildInfo info;
    await testBuildCommand(
      ['--dart-define=FOO=BAR', '--debug'],
      test: (command) async {
        info = await command.getBuildInfo();
      },
    );

    expect(info.dartDefines, contains('FOO=BAR'));
    expect(info.mode, equals(BuildMode.debug));
  });

  test('dart define from file works', () async {
    final fs = MemoryFileSystem.test();

    fs.file('config.json').writeAsStringSync('''
{"FOO": "BAR"}
''');

    late final BuildInfo info;
    await testBuildCommand(
      ['--dart-define-from-file=config.json', '--debug'],
      test: (command) async {
        info = await command.getBuildInfo();
      },
      fileSystem: fs,
    );

    expect(info.dartDefines, contains('FOO=BAR'));
    expect(info.mode, equals(BuildMode.debug));
  });

  test('profile mode works', () async {
    await testBuildCommand(
      ['--profile'],
      test: (command) async {
        expect((await command.getBuildInfo()).mode, equals(BuildMode.profile));
        expect(command.getBuildMode(), equals(BuildMode.profile));
        expect(command.getEngineFlavor(), equals(EngineFlavor.profile));
        expect(command.getIncludeDebugSymbols(), isFalse);
      },
    );
  });

  test('release mode works', () async {
    await testBuildCommand(
      ['--release'],
      test: (command) async {
        expect((await command.getBuildInfo()).mode, equals(BuildMode.release));
        expect(command.getBuildMode(), equals(BuildMode.release));
        expect(command.getEngineFlavor(), equals(EngineFlavor.release));
        expect(command.getIncludeDebugSymbols(), isFalse);
      },
    );
  });

  test('debug_unopt mode works', () async {
    await testBuildCommand(
      ['--debug-unoptimized'],
      test: (command) async {
        expect((await command.getBuildInfo()).mode, equals(BuildMode.debug));
        expect(command.getBuildMode(), equals(BuildMode.debug));
        expect(command.getEngineFlavor(), equals(EngineFlavor.debugUnopt));
        expect(command.getIncludeDebugSymbols(), isFalse);
      },
    );
  });

  test('debug symbols works', () async {
    await testBuildCommand(
      ['--debug-symbols'],
      test: (command) async {
        expect(command.getIncludeDebugSymbols(), isTrue);
      },
    );
  });

  test('tree-shake-icons works', () async {
    await testBuildCommand(
      ['--debug', '--tree-shake-icons'],
      test: (command) async {
        final info = await command.getBuildInfo();
        expect(info.treeShakeIcons, isFalse);
      },
    );

    await testBuildCommand(
      ['--profile', '--tree-shake-icons'],
      test: (command) async {
        final info = await command.getBuildInfo();
        expect(info.treeShakeIcons, isTrue);
      },
    );

    await testBuildCommand(
      ['--profile', '--no-tree-shake-icons'],
      test: (command) async {
        final info = await command.getBuildInfo();
        expect(info.treeShakeIcons, isFalse);
      },
    );
  });

  test('target path works', () async {
    await testBuildCommand(
      ['--target=lib/other_main.dart'],
      test: (command) async {
        expect(command.targetFile, 'lib/other_main.dart');
      },
    );
  });

  group('building', () {
    FileSystem fs;
    fltool.Platform platform;
    Logger logger;
    fltool.BuildSystem buildSystem;
    ProcessManager processManager;

    setUp(() {});
  });

  test('target path works', () async {
    final fs = MemoryFileSystem.test();
    final platform = fltool.FakePlatform();
    final logger = BufferLogger.test();

    final buildSystem = fltool.FlutterBuildSystem(
      fileSystem: fs,
      platform: platform,
      logger: logger,
    );

    final os = fltool.OperatingSystemUtils(
      fileSystem: fs,
      logger: logger,
      platform: platform,
      processManager: FakeProcessManager.any(),
    );

    final cache = fltool.Cache.test(
      fileSystem: fs,
      logger: logger,
      platform: platform,
      processManager: FakeProcessManager.any(),
    );

    final target = FlutterpiTargetPlatform.genericArmV7;

    final artifactPaths = FlutterpiArtifactPathsV2();

    final artifacts = OverrideGenSnapshotArtifacts.fromArtifactPaths(
      parent: fltool.CachedArtifacts(
        fileSystem: fs,
        platform: platform,
        cache: cache,
        operatingSystemUtils: os,
      ),
      engineCacheDir: cache.getArtifactDirectory('engine'),
      host: HostPlatform.linux_x64,
      target: target,
      artifactPaths: artifactPaths,
    );

    final buildEnv = fltool.Environment.test(
      fs.directory('test_build'),
      cacheDir: cache.getRoot(),
      fileSystem: fs,
      logger: logger,
      platform: platform,
      artifacts: artifacts,
      processManager: FakeProcessManager.empty(),
    );

    final buildTarget = ReleaseBundleFlutterpiAssets(
      flutterpiTargetPlatform: FlutterpiTargetPlatform.genericArmV7,
      hostPlatform: HostPlatform.linux_arm64,
      artifactPaths: artifactPaths,
    );

    await expectLater(buildSystem.build(buildTarget, buildEnv), completes);

    final fltool.ResolvedFiles inputs = buildTarget.fold<fltool.SourceVisitor>(
      fltool.SourceVisitor(buildEnv),
      (visitor, target) {
        for (final input in target.inputs) {
          input.accept(visitor);
        }

        return visitor;
      },
    );

    expect(
      inputs.sources,
      containsAll([
        hasPath('/cache/bin/cache/artifacts/engine/flutterpi-engine-armv7-generic-release/libflutter_engine.so'),
        hasPath('/cache/bin/cache/artifacts/engine/flutterpi-gen-snapshot-linux-x64-armv7-generic-release/gen_snapshot')
      ]),
    );
  });
}
