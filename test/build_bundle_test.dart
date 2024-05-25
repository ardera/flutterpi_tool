import 'dart:async';

import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/context_runner.dart' as context_runner;
import 'package:flutterpi_tool/src/build_bundle.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:test/test.dart';

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
}
