import 'dart:async';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/executable.dart';
import 'package:test/test.dart';

import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

import '../src/context.dart';
import '../src/fake_flutter_version.dart';
import '../src/fake_process_manager.dart';
import '../src/mock_app_builder.dart';
import '../src/mock_flutterpi_artifacts.dart';

void main() {
  late MemoryFileSystem fs;
  late fl.BufferLogger logger;
  late FlutterpiToolCommandRunner runner;
  late fl.Platform platform;
  late MockFlutterpiArtifacts flutterpiArtifacts;
  late MockAppBuilder appBuilder;

  // ignore: no_leading_underscores_for_local_identifiers
  Future<V> _runInTestContext<V>(
    FutureOr<V> Function() fn, {
    Map<Type, fl.Generator> overrides = const {},
  }) async {
    return await runInTestContext(
      fn,
      overrides: {
        fl.Logger: () => logger,
        ProcessManager: () => FakeProcessManager.empty(),
        FileSystem: () => fs,
        fl.FlutterVersion: () => FakeFlutterVersion(),
        Platform: () => platform,
        fl.Artifacts: () => flutterpiArtifacts,
        AppBuilder: () => appBuilder,
        ...overrides,
      },
    );
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    logger = fl.BufferLogger.test();
    runner = createFlutterpiCommandRunner();
    platform = fl.FakePlatform();
    flutterpiArtifacts = MockFlutterpiArtifacts();
    appBuilder = MockAppBuilder();

    fs.file('lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}');
  });

  test('simple dart defines work', () async {
    var buildWasCalled = false;
    appBuilder.buildFn = ({
      required FlutterpiHostPlatform host,
      required FlutterpiTargetPlatform target,
      required fl.BuildInfo buildInfo,
      required FilesystemLayout fsLayout,
      fl.FlutterProject? project,
      FlutterpiArtifacts? artifacts,
      String? mainPath,
      String manifestPath = fl.defaultManifestPath,
      String? applicationKernelFilePath,
      String? depfilePath,
      Directory? outDir,
      bool unoptimized = false,
      bool includeDebugSymbols = false,
      bool forceBundleFlutterpi = false,
    }) async {
      buildWasCalled = true;
      expect(buildInfo.dartDefines, contains('FOO=BAR'));
    };

    await _runInTestContext(() async {
      await runner.run(['build', '--dart-define=FOO=BAR', '--debug']);
    });

    expect(
      buildWasCalled,
      isTrue,
      reason: "Expected BuildSystem.build to be called",
    );
  });

  test('dart define from file works', () async {
    fs.file('config.json').writeAsStringSync('''
{"FOO": "BAR"}
''');

    var buildWasCalled = false;

    appBuilder.buildFn = ({
      required FlutterpiHostPlatform host,
      required FlutterpiTargetPlatform target,
      required fl.BuildInfo buildInfo,
      required FilesystemLayout fsLayout,
      fl.FlutterProject? project,
      FlutterpiArtifacts? artifacts,
      String? mainPath,
      String manifestPath = fl.defaultManifestPath,
      String? applicationKernelFilePath,
      String? depfilePath,
      Directory? outDir,
      bool unoptimized = false,
      bool includeDebugSymbols = false,
      bool forceBundleFlutterpi = false,
    }) async {
      expect(buildInfo.dartDefines, contains('FOO=BAR'));
      buildWasCalled = true;
    };

    await _runInTestContext(() async {
      await runner
          .run(['build', '--dart-define-from-file=config.json', '--debug']);
    });

    expect(
      buildWasCalled,
      isTrue,
      reason: "Expected BuildSystem.build to be called",
    );
  });

  group('build modes', () {
    test('debug mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(buildInfo.mode, equals(fl.BuildMode.debug));
        expect(unoptimized, isFalse);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--debug']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('profile mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(buildInfo.mode, equals(fl.BuildMode.profile));
        expect(unoptimized, isFalse);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--profile']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('release mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(buildInfo.mode, equals(fl.BuildMode.release));
        expect(unoptimized, isFalse);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--release']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('debug-unoptimized mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(buildInfo.mode, equals(fl.BuildMode.debug));
        expect(unoptimized, isTrue);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--debug-unoptimized']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });
  });

  group('--tree-shake-icons', () {
    test('debug mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(
          buildInfo.treeShakeIcons,
          isFalse,
          reason: 'Expected treeShakeIcons to be false in debug mode',
        );
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--debug', '--tree-shake-icons']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('profile mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(buildInfo.treeShakeIcons, isTrue);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--profile', '--tree-shake-icons']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('release mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(buildInfo.treeShakeIcons, isTrue);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--release', '--tree-shake-icons']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('debug-unoptimized mode works', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(
          buildInfo.treeShakeIcons,
          isFalse,
          reason:
              'Expected treeShakeIcons to be false in debug-unoptimized mode',
        );
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner
            .run(['build', '--debug-unoptimized', '--tree-shake-icons']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });
  });

  test('target path works', () async {
    var buildWasCalled = false;
    appBuilder.buildFn = ({
      required FlutterpiHostPlatform host,
      required FlutterpiTargetPlatform target,
      required fl.BuildInfo buildInfo,
      required FilesystemLayout fsLayout,
      fl.FlutterProject? project,
      FlutterpiArtifacts? artifacts,
      String? mainPath,
      String manifestPath = fl.defaultManifestPath,
      String? applicationKernelFilePath,
      String? depfilePath,
      Directory? outDir,
      bool unoptimized = false,
      bool includeDebugSymbols = false,
      bool forceBundleFlutterpi = false,
    }) async {
      expect(mainPath, equals('lib/other_main.dart'));
      buildWasCalled = true;
    };

    fs.file('lib/other_main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}');

    await _runInTestContext(() async {
      await runner.run(['build', '--target=lib/other_main.dart']);
    });

    expect(
      buildWasCalled,
      isTrue,
      reason: "Expected BuildSystem.build to be called",
    );
  });

  group('--fs-layout', () {
    test('default', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(fsLayout, equals(FilesystemLayout.flutterPi));
        expect(forceBundleFlutterpi, isFalse);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('flutter-pi', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(fsLayout, equals(FilesystemLayout.flutterPi));
        expect(forceBundleFlutterpi, isFalse);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('meta-flutter', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(fsLayout, equals(FilesystemLayout.metaFlutter));
        expect(forceBundleFlutterpi, isFalse);
        buildWasCalled = true;
      };

      await _runInTestContext(() async {
        await runner.run(['build', '--fs-layout=meta-flutter']);
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('flutter-pi, --flutterpi-binary=test', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(fsLayout, equals(FilesystemLayout.flutterPi));
        expect(forceBundleFlutterpi, isTrue);
        buildWasCalled = true;
      };

      fs.currentDirectory
          .childFile('test')
          .writeAsStringSync('test-flutterpi-binary');

      await _runInTestContext(() async {
        await runner.run(
          ['build', '--fs-layout=flutter-pi', '--flutterpi-binary=test'],
        );
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });

    test('meta-flutter, --flutterpi-binary=test', () async {
      var buildWasCalled = false;
      appBuilder.buildFn = ({
        required FlutterpiHostPlatform host,
        required FlutterpiTargetPlatform target,
        required fl.BuildInfo buildInfo,
        required FilesystemLayout fsLayout,
        fl.FlutterProject? project,
        FlutterpiArtifacts? artifacts,
        String? mainPath,
        String manifestPath = fl.defaultManifestPath,
        String? applicationKernelFilePath,
        String? depfilePath,
        Directory? outDir,
        bool unoptimized = false,
        bool includeDebugSymbols = false,
        bool forceBundleFlutterpi = false,
      }) async {
        expect(fsLayout, equals(FilesystemLayout.metaFlutter));
        expect(forceBundleFlutterpi, isTrue);
        buildWasCalled = true;
      };

      fs.currentDirectory
          .childFile('test')
          .writeAsStringSync('test-flutterpi-binary');

      await _runInTestContext(() async {
        await runner.run(
          ['build', '--fs-layout=meta-flutter', '--flutterpi-binary=test'],
        );
      });

      expect(
        buildWasCalled,
        isTrue,
        reason: "Expected BuildSystem.build to be called",
      );
    });
  });

  test('build system artifacts is a flutterpi artifacts', () async {
    var buildWasCalled = false;
    appBuilder.buildFn = ({
      required FlutterpiHostPlatform host,
      required FlutterpiTargetPlatform target,
      required fl.BuildInfo buildInfo,
      required FilesystemLayout fsLayout,
      fl.FlutterProject? project,
      FlutterpiArtifacts? artifacts,
      String? mainPath,
      String manifestPath = fl.defaultManifestPath,
      String? applicationKernelFilePath,
      String? depfilePath,
      Directory? outDir,
      bool unoptimized = false,
      bool includeDebugSymbols = false,
      bool forceBundleFlutterpi = false,
    }) async {
      expect(artifacts ?? globals.artifacts, isA<FlutterpiArtifacts>());

      buildWasCalled = true;
    };

    await _runInTestContext(() async {
      await runner.run(['build']);
    });

    expect(
      buildWasCalled,
      isTrue,
      reason: "Expected BuildSystem.build to be called",
    );
  });
}
