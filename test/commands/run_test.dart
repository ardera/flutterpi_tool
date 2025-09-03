import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/executable.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

import '../src/context.dart';
import '../src/fake_device.dart';
import '../src/fake_device_manager.dart';
import '../src/fake_flutter_version.dart';
import '../src/fake_process_manager.dart';
import '../src/mock_app_builder.dart';
import '../src/mock_flutterpi_artifacts.dart';
import '../src/test_feature_flags.dart';

void main() {
  late MemoryFileSystem fs;
  late fl.BufferLogger logger;
  late FlutterpiToolCommandRunner runner;
  late fl.Platform platform;
  late MockFlutterpiArtifacts flutterpiArtifacts;
  late MockAppBuilder appBuilder;
  late FakeDeviceManager deviceManager;

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
        AppBuilder: () => appBuilder,
        fl.FeatureFlags: () => TestFeatureFlags(),
        fl.DeviceManager: () => deviceManager,
        fl.Terminal: () => fl.Terminal.test(),
        fl.AnsiTerminal: () => FakeTerminal(),
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
    deviceManager = FakeDeviceManager();

    fs.file('lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}');

    fs.file('pubspec.yaml').createSync();
  });

  test('specifying device id works', () async {
    deviceManager.devices.add(
      FakeDevice(id: 'test-device-2')
        ..isSupportedForProjectFn = ((_) => true)
        ..supportsRuntimeModeFn = ((_) => false),
    );

    // This is fairly hacky, but works for now.
    try {
      await _runInTestContext(() async {
        await runner.run(['run', '-d', 'test-device', '--no-pub']);
      });
      fail('Expected tool exit to be thrown.');
    } on fl.ToolExit catch (e) {
      expect(e.message, 'Debugmode is not supported by Test Device.');
    }

    expect(deviceManager.specifiedDeviceId, equals('test-device'));
  });
}

class FakeTerminal extends Fake implements fl.AnsiTerminal {
  @override
  set usesTerminalUi(bool _usesTerminalUi) {}
}
