import 'dart:async';

import 'package:file/memory.dart';
import 'package:file/src/interface/file_system.dart';

import 'package:flutterpi_tool/src/cli/command_runner.dart' as src;
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/config.dart' as src;
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';
import 'package:flutterpi_tool/src/executable.dart' as src;

import 'package:test/test.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fltool;

import '../src/context.dart';
import '../src/fake_device.dart';
import '../src/fake_device_manager.dart';
import '../src/fake_process_manager.dart';

class MockConfig implements src.FlutterPiToolConfig {
  MockConfig();

  void Function(src.DeviceConfigEntry)? addDeviceFn;

  @override
  void addDevice(src.DeviceConfigEntry entry) {
    addDeviceFn!(entry);
  }

  bool Function(String id)? containsDeviceFn;

  @override
  bool containsDevice(String id) {
    if (containsDeviceFn == null) {
      throw UnimplementedError('containsDeviceFn is not set');
    }
    return containsDeviceFn!(id);
  }

  List<src.DeviceConfigEntry> Function()? getDevicesFn;

  @override
  List<src.DeviceConfigEntry> getDevices() {
    if (getDevicesFn == null) {
      throw UnimplementedError('getDevicesFn is not set');
    }
    return getDevicesFn!();
  }

  src.DeviceConfigEntry? Function(String id)? removeDeviceFn;

  @override
  void removeDevice(String id) {
    if (removeDeviceFn == null) {
      throw UnimplementedError('removeDeviceFn is not set');
    }
    removeDeviceFn!(id);
  }
}

class MockSshUtils implements SshUtils {
  // Function fields for mocking behavior
  List<String> Function({
    bool? interactive,
    bool? allocateTTY,
    bool? exitOnForwardFailure,
    Iterable<(int, int)> remotePortForwards,
    Iterable<(int, int)> localPortForwards,
    Iterable<String> extraArgs,
    String? remote,
    String? command,
  })? buildSshCommandFn;

  List<String> Function(Iterable<String> groups)?
      buildUsermodAddGroupsCommandFn;

  Future<void> Function({
    required String localPath,
    required String remotePath,
    String? remote,
  })? copyFn;

  String? defaultRemoteValue;

  Future<String> Function({
    Iterable<String>? args,
    String? remote,
    Duration? timeout,
  })? idFn;

  Future<void> Function({
    Iterable<String>? args,
    String? remote,
    Duration? timeout,
  })? makeExecutableFn;

  fltool.ProcessUtils? processUtilsValue;

  Future<bool> Function(Iterable<String> groups, {String? remote})?
      remoteUserBelongsToGroupsFn;

  Future<fltool.RunResult> Function({
    String? remote,
    String? command,
    Iterable<String> extraArgs,
    bool throwOnError,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries,
    bool? allocateTTY,
    Iterable<(int, int)> localPortForwards,
    Iterable<(int, int)> remotePortForwards,
    bool? exitOnForwardFailure,
  })? runSshFn;

  Future<fltool.RunResult> Function({
    String? remote,
    required String localPath,
    required String remotePath,
    Iterable<String> extraArgs,
    bool throwOnError,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries,
    bool recursive,
  })? scpFn;

  String? scpExecutableValue;
  String? sshExecutableValue;

  Future<fltool.Process> Function({
    String? remote,
    String? command,
    Iterable<String> extraArgs,
    String? workingDirectory,
    Map<String, String>? environment,
    bool? allocateTTY,
    Iterable<(int, int)> remotePortForwards,
    Iterable<(int, int)> localPortForwards,
    bool? exitOnForwardFailure,
    fltool.ProcessStartMode mode,
  })? startSshFn;

  Future<bool> Function({String? remote, Duration? timeout, bool throwOnError})?
      tryConnectFn;

  Future<String> Function({
    Iterable<String>? args,
    String? remote,
    Duration? timeout,
  })? unameFn;

  @override
  List<String> buildSshCommand({
    bool? interactive = false,
    bool? allocateTTY,
    bool? exitOnForwardFailure,
    Iterable<(int, int)> remotePortForwards = const [],
    Iterable<(int, int)> localPortForwards = const [],
    Iterable<String> extraArgs = const [],
    String? remote,
    String? command,
  }) {
    if (buildSshCommandFn == null) {
      throw UnimplementedError('buildSshCommandFn is not set');
    }
    return buildSshCommandFn!(
      interactive: interactive,
      allocateTTY: allocateTTY,
      exitOnForwardFailure: exitOnForwardFailure,
      remotePortForwards: remotePortForwards,
      localPortForwards: localPortForwards,
      extraArgs: extraArgs,
      remote: remote,
      command: command,
    );
  }

  @override
  List<String> buildUsermodAddGroupsCommand(Iterable<String> groups) {
    if (buildUsermodAddGroupsCommandFn == null) {
      throw UnimplementedError('buildUsermodAddGroupsCommandFn is not set');
    }
    return buildUsermodAddGroupsCommandFn!(groups);
  }

  @override
  Future<void> copy({
    required String localPath,
    required String remotePath,
    String? remote,
  }) {
    if (copyFn == null) throw UnimplementedError('copyFn is not set');
    return copyFn!(
      localPath: localPath,
      remotePath: remotePath,
      remote: remote,
    );
  }

  @override
  String get defaultRemote {
    if (defaultRemoteValue == null) {
      throw UnimplementedError('defaultRemoteValue is not set');
    }
    return defaultRemoteValue!;
  }

  @override
  Future<String> id({
    Iterable<String>? args,
    String? remote,
    Duration? timeout,
  }) {
    if (idFn == null) throw UnimplementedError('idFn is not set');
    return idFn!(args: args, remote: remote, timeout: timeout);
  }

  @override
  Future<void> makeExecutable({
    Iterable<String>? args,
    String? remote,
    Duration? timeout,
  }) {
    if (makeExecutableFn == null) {
      throw UnimplementedError('makeExecutableFn is not set');
    }
    return makeExecutableFn!(args: args, remote: remote, timeout: timeout);
  }

  @override
  fltool.ProcessUtils get processUtils {
    if (processUtilsValue == null) {
      throw UnimplementedError('processUtilsValue is not set');
    }
    return processUtilsValue!;
  }

  @override
  Future<bool> remoteUserBelongsToGroups(
    Iterable<String> groups, {
    String? remote,
  }) {
    if (remoteUserBelongsToGroupsFn == null) {
      throw UnimplementedError('remoteUserBelongsToGroupsFn is not set');
    }
    return remoteUserBelongsToGroupsFn!(groups, remote: remote);
  }

  @override
  Future<fltool.RunResult> runSsh({
    String? remote,
    String? command,
    Iterable<String> extraArgs = const [],
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
    bool? allocateTTY,
    Iterable<(int, int)> localPortForwards = const [],
    Iterable<(int, int)> remotePortForwards = const [],
    bool? exitOnForwardFailure,
  }) {
    if (runSshFn == null) throw UnimplementedError('runSshFn is not set');
    return runSshFn!(
      remote: remote,
      command: command,
      extraArgs: extraArgs,
      throwOnError: throwOnError,
      workingDirectory: workingDirectory,
      environment: environment,
      timeout: timeout,
      timeoutRetries: timeoutRetries,
      allocateTTY: allocateTTY,
      localPortForwards: localPortForwards,
      remotePortForwards: remotePortForwards,
      exitOnForwardFailure: exitOnForwardFailure,
    );
  }

  @override
  Future<fltool.RunResult> scp({
    String? remote,
    required String localPath,
    required String remotePath,
    Iterable<String> extraArgs = const [],
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
    bool recursive = true,
  }) {
    if (scpFn == null) throw UnimplementedError('scpFn is not set');
    return scpFn!(
      remote: remote,
      localPath: localPath,
      remotePath: remotePath,
      extraArgs: extraArgs,
      throwOnError: throwOnError,
      workingDirectory: workingDirectory,
      environment: environment,
      timeout: timeout,
      timeoutRetries: timeoutRetries,
      recursive: recursive,
    );
  }

  @override
  String get scpExecutable {
    if (scpExecutableValue == null) {
      throw UnimplementedError('scpExecutableValue is not set');
    }
    return scpExecutableValue!;
  }

  @override
  String get sshExecutable {
    if (sshExecutableValue == null) {
      throw UnimplementedError('sshExecutableValue is not set');
    }
    return sshExecutableValue!;
  }

  @override
  Future<fltool.Process> startSsh({
    String? remote,
    String? command,
    Iterable<String> extraArgs = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    bool? allocateTTY,
    Iterable<(int, int)> remotePortForwards = const [],
    Iterable<(int, int)> localPortForwards = const [],
    bool? exitOnForwardFailure,
    fltool.ProcessStartMode mode = fltool.ProcessStartMode.normal,
  }) {
    if (startSshFn == null) throw UnimplementedError('startSshFn is not set');
    return startSshFn!(
      remote: remote,
      command: command,
      extraArgs: extraArgs,
      workingDirectory: workingDirectory,
      environment: environment,
      allocateTTY: allocateTTY,
      remotePortForwards: remotePortForwards,
      localPortForwards: localPortForwards,
      exitOnForwardFailure: exitOnForwardFailure,
      mode: mode,
    );
  }

  @override
  Future<bool> tryConnect({
    String? remote,
    Duration? timeout,
    bool throwOnError = false,
  }) {
    if (tryConnectFn == null) {
      throw UnimplementedError('tryConnectFn is not set');
    }
    return tryConnectFn!(
      remote: remote,
      timeout: timeout,
      throwOnError: throwOnError,
    );
  }

  @override
  Future<String> uname({
    Iterable<String>? args,
    String? remote,
    Duration? timeout,
  }) {
    if (unameFn == null) throw UnimplementedError('unameFn is not set');
    return unameFn!(args: args, remote: remote, timeout: timeout);
  }
}

void main() {
  late MemoryFileSystem fs;
  late fltool.BufferLogger logger;
  late src.FlutterpiToolCommandRunner runner;
  late MockConfig config;
  late MockSshUtils sshUtils;

  // ignore: no_leading_underscores_for_local_identifiers
  Future<V> _runInTestContext<V>(
    FutureOr<V> Function() fn, {
    Map<Type, fltool.Generator> overrides = const {},
  }) async {
    return await runInTestContext(
      fn,
      overrides: {
        src.FlutterPiToolConfig: () => config,
        fltool.Logger: () => logger,
        ProcessManager: () => FakeProcessManager.empty(),
        FileSystem: () => fs,
        SshUtils: () => sshUtils,
        ...overrides,
      },
    );
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    logger = fltool.BufferLogger.test();
    runner = src.createFlutterpiCommandRunner();
    config = MockConfig();
    sshUtils = MockSshUtils()
      ..remoteUserBelongsToGroupsFn = (groups, {remote}) async {
        // Mock implementation that always returns true for testing
        return true;
      }
      ..tryConnectFn = ({remote, timeout, throwOnError = false}) async {
        // Mock implementation that always returns true for testing
        return true;
      };
  });

  group('devices add', () {
    test('adds entry to devices config', () async {
      var addDeviceWasCalled = false;
      config
        ..addDeviceFn = (entry) {
          expect(
            entry,
            src.DeviceConfigEntry(
              id: 'test-device',
              sshExecutable: null,
              sshRemote: 'test-device',
              remoteInstallPath: null,
            ),
          );
          addDeviceWasCalled = true;
        }
        ..containsDeviceFn = (id) {
          return false;
        };

      await _runInTestContext(() async {
        await runner.run(['devices', 'add', 'test-device']);
      });

      expect(
        addDeviceWasCalled,
        isTrue,
        reason: 'addDeviceFn should have been called',
      );
    });

    test('checks if the device already exists', () async {
      var addDeviceWasCalled = false;
      var containsDeviceWasCalled = false;
      config
        ..addDeviceFn = (entry) {
          expect(
            containsDeviceWasCalled,
            isTrue,
            reason: 'containsDeviceFn should have been called before '
                'FlutterPiToolConfig.addDevice',
          );
          addDeviceWasCalled = true;
        }
        ..containsDeviceFn = (id) {
          containsDeviceWasCalled = true;
          return false;
        };

      await _runInTestContext(() async {
        await runner.run(['devices', 'add', 'test-device']);
      });

      expect(
        containsDeviceWasCalled,
        isTrue,
        reason: 'containsDeviceFn should have been called',
      );

      expect(
        addDeviceWasCalled,
        isTrue,
        reason: 'addDeviceFn should have been called',
      );
    });

    test('handles display-size', () async {
      var addDeviceWasCalled = false;
      config
        ..addDeviceFn = (entry) {
          expect(
            entry,
            src.DeviceConfigEntry(
              id: 'test-device',
              sshExecutable: null,
              sshRemote: 'test-device',
              remoteInstallPath: null,
              displaySizeMillimeters: (12, 34),
            ),
          );
          addDeviceWasCalled = true;
        }
        ..containsDeviceFn = (id) {
          return false;
        };

      await _runInTestContext(() async {
        await runner
            .run(['devices', 'add', '--display-size=12x34', 'test-device']);
      });

      expect(
        addDeviceWasCalled,
        isTrue,
        reason: 'addDeviceFn should have been called',
      );
    });

    group('handles dummy-display', () {
      test('without size', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'test-device',
                remoteInstallPath: null,
                useDummyDisplay: true,
                dummyDisplaySize: null,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner
              .run(['devices', 'add', '--dummy-display', 'test-device']);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });

      test('with size', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'test-device',
                remoteInstallPath: null,
                useDummyDisplay: true,
                dummyDisplaySize: (12, 34),
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner.run([
            'devices',
            'add',
            '--dummy-display-size=12x34',
            'test-device',
          ]);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });
    });

    group('id and ssh remote configuration', () {
      test('specifying ssh remote without username', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'test-device',
                remoteInstallPath: null,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner.run(['devices', 'add', 'test-device']);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });

      test('specifying ssh remote with username', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'username@test-device',
                remoteInstallPath: null,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner.run(['devices', 'add', 'username@test-device']);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });

      test('specifying ssh remote, but --id is also given', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-id',
                sshExecutable: null,
                sshRemote: 'username@test-device',
                remoteInstallPath: null,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            expect(id, 'test-id');
            return false;
          };

        await _runInTestContext(() async {
          await runner
              .run(['devices', 'add', 'username@test-device', '--id=test-id']);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });
    });

    group('--fs-layout', () {
      test('default', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'test-device',
                remoteInstallPath: null,
                filesystemLayout: FilesystemLayout.flutterPi,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner.run(['devices', 'add', 'test-device']);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });

      test('flutter-pi', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'test-device',
                remoteInstallPath: null,
                filesystemLayout: FilesystemLayout.flutterPi,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner
              .run(['devices', 'add', 'test-device', '--fs-layout=flutter-pi']);
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });

      test('meta-flutter', () async {
        var addDeviceWasCalled = false;
        config
          ..addDeviceFn = (entry) {
            expect(
              entry,
              src.DeviceConfigEntry(
                id: 'test-device',
                sshExecutable: null,
                sshRemote: 'test-device',
                remoteInstallPath: null,
                filesystemLayout: FilesystemLayout.metaFlutter,
              ),
            );
            addDeviceWasCalled = true;
          }
          ..containsDeviceFn = (id) {
            return false;
          };

        await _runInTestContext(() async {
          await runner.run(
            ['devices', 'add', 'test-device', '--fs-layout=meta-flutter'],
          );
        });

        expect(
          addDeviceWasCalled,
          isTrue,
          reason: 'addDeviceFn should have been called',
        );
      });
    });

    group('diagnostics', () {
      test('attempts connecting to new device', () async {
        var tryConnectWasCalled = false;
        var remoteUserBelongsToGroupsWasCalled = false;

        config
          ..addDeviceFn = (entry) {}
          ..containsDeviceFn = (id) {
            return false;
          };

        sshUtils.tryConnectFn = ({
          timeout,
          throwOnError = false,
          remote,
        }) async {
          tryConnectWasCalled = true;
          expect(remote, 'test-device');
          return true;
        };

        sshUtils.remoteUserBelongsToGroupsFn = (groups, {remote}) async {
          remoteUserBelongsToGroupsWasCalled = true;
          expect(groups, unorderedEquals(['render', 'video', 'input']));
          expect(remote, equals('test-device'));
          return true;
        };

        await _runInTestContext(
          () async {
            await runner.run(['devices', 'add', 'test-device']);
          },
          overrides: {
            SshUtils: () => sshUtils,
          },
        );

        expect(
          tryConnectWasCalled,
          isTrue,
          reason: 'SshUtils.tryConnect should have been called',
        );
        expect(
          remoteUserBelongsToGroupsWasCalled,
          isTrue,
          reason: 'SshUtils.remoteUserBelongsToGroups should have been called',
        );
      });

      test('prints error when connecting to device fails', () async {
        config
          ..addDeviceFn = (entry) {}
          ..containsDeviceFn = (id) {
            return false;
          };

        sshUtils.tryConnectFn = ({
          timeout,
          throwOnError = false,
          remote,
        }) async {
          expect(throwOnError, isFalse);
          return false;
        };

        await _runInTestContext(() async {
          await runner.run(['devices', 'add', 'test-device']);
        });

        expect(
          logger.errorText,
          contains(
            'Connecting to device failed. '
            'Make sure the device is reachable and public-key authentication is set up correctly. '
            'If you wish to add the device anyway, use --force.',
          ),
        );
      });

      test('does not attempt connecting to new device with --force', () async {
        config
          ..addDeviceFn = (entry) {}
          ..containsDeviceFn = (id) {
            return false;
          };

        sshUtils.tryConnectFn = ({
          timeout,
          throwOnError = false,
          remote,
        }) async {
          fail('SshUtils.tryConnect should not have been called');
        };

        await _runInTestContext(
          () async {
            await runner.run(['devices', 'add', 'test-device', '--force']);
          },
        );
      });
    });
  });

  group('devices list', () {
    late FakeDeviceManager deviceManager;

    setUp(() {
      deviceManager = FakeDeviceManager();
      deviceManager.devices = [
        FakeDevice(),
      ];
    });

    test('lists devices from device manager', () async {
      await _runInTestContext(
        () async {
          await runner.run(['devices', 'list']);
        },
        overrides: {
          fltool.DeviceManager: () => deviceManager,
        },
      );

      expect(logger.errorText, isEmpty);
      expect(logger.statusText, contains('test-device'));
    });
  });

  group('devices remove', () {
    test('works', () async {
      var removeDeviceWasCalled = false;

      config
        ..removeDeviceFn = (id) {
          expect(id, 'test-device');
          removeDeviceWasCalled = true;

          return src.DeviceConfigEntry(
            id: id,
            sshExecutable: '',
            sshRemote: '',
            remoteInstallPath: '',
          );
        }
        ..containsDeviceFn = (id) {
          return true; // Device exists
        };

      await _runInTestContext(() async {
        await runner.run(['devices', 'remove', 'test-device']);
      });

      expect(
        removeDeviceWasCalled,
        isTrue,
        reason: 'removeDeviceFn should have been called',
      );
    });
  });
}
