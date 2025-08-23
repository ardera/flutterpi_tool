import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutterpi_tool/src/build_system/targets.dart';
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';

import 'src/context.dart';
import 'src/fake_flutter_version.dart';
import 'src/fake_os_utils.dart';
import 'src/fake_process_manager.dart';
import 'src/mock_build_system.dart';
import 'src/mock_flutterpi_artifacts.dart';

void main() {
  late MemoryFileSystem fs;
  late fl.BufferLogger logger;
  late fl.Platform platform;
  late MockFlutterpiArtifacts flutterpiArtifacts;
  late MockBuildSystem buildSystem;
  late FakeMoreOperatingSystemUtils moreOs;
  late AppBuilder appBuilder;

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
        fl.FileSystem: () => fs,
        fl.FlutterVersion: () => FakeFlutterVersion(),
        fl.Platform: () => platform,
        fl.Artifacts: () => flutterpiArtifacts,
        fl.BuildSystem: () => buildSystem,
        ...overrides,
      },
    );
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    logger = fl.BufferLogger.test();
    platform = fl.FakePlatform();
    flutterpiArtifacts = MockFlutterpiArtifacts();
    buildSystem = MockBuildSystem();
    moreOs = FakeMoreOperatingSystemUtils();
    appBuilder = AppBuilder(
      operatingSystemUtils: moreOs,
      buildSystem: buildSystem,
    );
  });

  test('calls build system', () async {
    var buildWasCalled = false;
    buildSystem.buildFn = (
      fl.Target target,
      fl.Environment environment, {
      fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
    }) async {
      buildWasCalled = true;
      return fl.BuildResult(success: true);
    };

    await _runInTestContext(
      () async => await appBuilder.build(
        host: FlutterpiHostPlatform.linuxRV64,
        target: FlutterpiTargetPlatform.genericArmV7,
        buildInfo: fl.BuildInfo.debug,
        fsLayout: FilesystemLayout.flutterPi,
      ),
    );

    expect(buildWasCalled, isTrue);
  });

  test('passes flutterpi target platform correctly', () async {
    var buildWasCalled = false;
    buildSystem.buildFn = (
      fl.Target target,
      fl.Environment environment, {
      fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
    }) async {
      expect(
        environment.defines['flutterpi-target'],
        equals('riscv64-generic'),
      );
      expect(
        (target as DebugBundleFlutterpiAssets).target,
        equals(FlutterpiTargetPlatform.genericRiscv64),
      );

      buildWasCalled = true;
      return fl.BuildResult(success: true);
    };

    await _runInTestContext(
      () async => await appBuilder.build(
        host: FlutterpiHostPlatform.linuxRV64,
        target: FlutterpiTargetPlatform.genericRiscv64,
        buildInfo: fl.BuildInfo.debug,
        fsLayout: FilesystemLayout.flutterPi,
      ),
    );

    expect(buildWasCalled, isTrue);
  });

  test('passes target path correctly', () async {
    var buildWasCalled = false;
    buildSystem.buildFn = (
      fl.Target target,
      fl.Environment environment, {
      fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
    }) async {
      expect(
        environment.defines[fl.kTargetFile],
        equals('lib/main_flutterpi.dart'),
      );

      buildWasCalled = true;
      return fl.BuildResult(success: true);
    };

    await _runInTestContext(
      () async => await appBuilder.build(
        host: FlutterpiHostPlatform.linuxRV64,
        target: FlutterpiTargetPlatform.genericRiscv64,
        buildInfo: fl.BuildInfo.debug,
        fsLayout: FilesystemLayout.flutterPi,
        mainPath: 'lib/main_flutterpi.dart',
      ),
    );

    expect(buildWasCalled, isTrue);
  });

  group('--fs-layout', () {
    group('meta-flutter', () {
      test('creates targets with meta-flutter layout', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterAssets>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          expect(
            subTargets.whereType<CopyIcudtl>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          expect(
            subTargets.whereType<CopyFlutterpiEngine>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.build(
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
          ),
        );

        expect(buildWasCalled, isTrue);
      });

      test(
          'does not bundle a flutterpi binary if forceBundleFlutterpi is not passed',
          () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterpiBinary>(),
            isEmpty,
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        final bundle = await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
            forceBundleFlutterpi: false,
          ),
        );

        expect(buildWasCalled, isTrue);
        expect(bundle.includesFlutterpiBinary, isFalse);
      });

      test('does bundle a flutterpi binary if forceBundleFlutterpi is passed',
          () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterpiBinary>(),
            hasLength(1),
          );

          expect(
            subTargets.whereType<CopyFlutterpiBinary>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        final bundle = await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
            forceBundleFlutterpi: true,
          ),
        );

        expect(buildWasCalled, isTrue);
        expect(bundle.includesFlutterpiBinary, isTrue);
      });

      test('default output directory is build/<target>-meta-flutter', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          expect(
            environment.outputDir.path,
            equals('build/flutter-pi/meta-flutter-riscv64-generic'),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
            forceBundleFlutterpi: true,
          ),
        );

        expect(buildWasCalled, isTrue);
      });
    });

    group('flutter-pi', () {
      test('creates targets with flutter-pi layout', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterAssets>().single.layout,
            equals(FilesystemLayout.flutterPi),
          );

          expect(
            subTargets.whereType<CopyIcudtl>().single.layout,
            equals(FilesystemLayout.flutterPi),
          );

          expect(
            subTargets.whereType<CopyFlutterpiEngine>().single.layout,
            equals(FilesystemLayout.flutterPi),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.build(
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.flutterPi,
          ),
        );

        expect(buildWasCalled, isTrue);
      });

      test('always bundles a flutterpi binary', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterpiBinary>(),
            hasLength(1),
          );

          expect(
            subTargets.whereType<CopyFlutterpiBinary>().single.layout,
            equals(FilesystemLayout.flutterPi),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.build(
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.flutterPi,
          ),
        );

        expect(buildWasCalled, isTrue);
      });

      test('default output directory is build/<target>', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          expect(
            environment.outputDir.path,
            equals('build/flutter-pi/riscv64-generic'),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterpiHostPlatform.linuxRV64,
            target: FlutterpiTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.flutterPi,
            forceBundleFlutterpi: true,
          ),
        );

        expect(buildWasCalled, isTrue);
      });
    });
  });

  group('debug symbols', () {
    test('are included', () async {
      var buildWasCalled = false;
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        final subTargets = (target as fl.CompositeTarget).dependencies;

        expect(
          subTargets
              .whereType<CopyFlutterpiEngine>()
              .single
              .includeDebugSymbols,
          isTrue,
        );

        buildWasCalled = true;
        return fl.BuildResult(success: true);
      };

      await _runInTestContext(
        () async => await appBuilder.build(
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterPi,
          includeDebugSymbols: true,
        ),
      );

      expect(buildWasCalled, isTrue);
    });

    test('are not included', () async {
      var buildWasCalled = false;
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        final subTargets = (target as fl.CompositeTarget).dependencies;

        expect(
          subTargets
              .whereType<CopyFlutterpiEngine>()
              .single
              .includeDebugSymbols,
          isFalse,
        );

        buildWasCalled = true;
        return fl.BuildResult(success: true);
      };

      await _runInTestContext(
        () async => await appBuilder.build(
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterPi,
          includeDebugSymbols: false,
        ),
      );

      expect(buildWasCalled, isTrue);
    });
  });

  group('bundle binaries', () {
    test('binary paths for --fs-layout=flutter-pi', () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterPi,
          forceBundleFlutterpi: false,
        ),
      ) as PrebuiltFlutterpiAppBundle;

      expect(
        bundle.binaries.map(
          (file) =>
              p.relative(file.path, from: 'build/flutter-pi/riscv64-generic'),
        ),
        unorderedEquals([
          'flutter-pi',
          'libflutter_engine.so',
        ]),
      );
    });

    test('binary paths for --fs-layout=flutter-pi and include debug symbols',
        () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterPi,
          includeDebugSymbols: true,
          forceBundleFlutterpi: false,
        ),
      ) as PrebuiltFlutterpiAppBundle;

      expect(
        bundle.binaries.map(
          (file) =>
              p.relative(file.path, from: 'build/flutter-pi/riscv64-generic'),
        ),
        unorderedEquals([
          'flutter-pi',
          'libflutter_engine.dbgsyms',
          'libflutter_engine.so',
        ]),
      );
    });

    test('binary paths for --fs-layout=meta-flutter', () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.metaFlutter,
          forceBundleFlutterpi: false,
        ),
      ) as PrebuiltFlutterpiAppBundle;

      expect(
        bundle.binaries.map(
          (file) => p.relative(
            file.path,
            from: 'build/flutter-pi/meta-flutter-riscv64-generic',
          ),
        ),
        unorderedEquals([
          'lib/libflutter_engine.so',
        ]),
      );
    });

    test(
        'binary paths for --fs-layout=meta-flutter with force bundle flutterpi',
        () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.metaFlutter,
          forceBundleFlutterpi: true,
        ),
      ) as PrebuiltFlutterpiAppBundle;

      expect(
        bundle.binaries.map(
          (file) => p.relative(
            file.path,
            from: 'build/flutter-pi/meta-flutter-riscv64-generic',
          ),
        ),
        unorderedEquals([
          'bin/flutter-pi',
          'lib/libflutter_engine.so',
        ]),
      );
    });

    test('binary paths for --fs-layout=meta-flutter with include debug symbols',
        () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterpiHostPlatform.linuxRV64,
          target: FlutterpiTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.metaFlutter,
          includeDebugSymbols: true,
          forceBundleFlutterpi: false,
        ),
      ) as PrebuiltFlutterpiAppBundle;

      expect(
        bundle.binaries.map(
          (file) => p.relative(
            file.path,
            from: 'build/flutter-pi/meta-flutter-riscv64-generic',
          ),
        ),
        unorderedEquals([
          'lib/libflutter_engine.dbgsyms',
          'lib/libflutter_engine.so',
        ]),
      );
    });
  });
}
