import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late FakePlatform platform;
  late BufferLogger logger;
  late FlutterPiToolConfig config;

  setUp(() {
    fs = MemoryFileSystem.test();
    platform = FakePlatform();
    logger = BufferLogger.test();
    config =
        FlutterPiToolConfig.test(fs: fs, logger: logger, platform: platform);
  });

  test('adding a config', () {
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: true,
        dummyDisplaySize: (3, 4),
      ),
    );

    final file = fs.file('.flutter_test');

    // expect that the config file exists
    expect(file.existsSync(), isTrue);

    // expect that it's valid json
    late final dynamic json;
    expect(
      () => json = jsonDecode(file.readAsStringSync()),
      returnsNormally,
    );

    expect(
      json,
      <String, dynamic>{
        'devices': <dynamic>[
          {
            'id': 'test-id',
            'sshExecutable': 'test-ssh-executable',
            'sshRemote': 'test-ssh-remote',
            'remoteInstallPath': 'test-remote-install-path',
            'displaySizeMillimeters': [1, 2],
            'devicePixelRatio': 1.23,
            'useDummyDisplay': true,
            'dummyDisplaySize': [3, 4],
          },
        ],
      },
    );
  });

  test('adding two configs', () {
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id-2',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );

    expect(
      jsonDecode(fs.file('.flutter_test').readAsStringSync()),
      <String, dynamic>{
        'devices': <dynamic>[
          {
            'id': 'test-id',
            'sshExecutable': 'test-ssh-executable',
            'sshRemote': 'test-ssh-remote',
            'remoteInstallPath': 'test-remote-install-path',
            'displaySizeMillimeters': [1, 2],
            'devicePixelRatio': 1.23,
            'dummyDisplaySize': [3, 4],
          },
          {
            'id': 'test-id-2',
            'sshExecutable': 'test-ssh-executable',
            'sshRemote': 'test-ssh-remote',
            'remoteInstallPath': 'test-remote-install-path',
            'displaySizeMillimeters': [1, 2],
            'devicePixelRatio': 1.23,
            'dummyDisplaySize': [3, 4],
          },
        ],
      },
    );
  });

  test('removing a config', () {
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id-2',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );

    config.removeDevice('test-id');

    expect(
      jsonDecode(fs.file('.flutter_test').readAsStringSync()),
      <String, dynamic>{
        'devices': <dynamic>[
          {
            'id': 'test-id-2',
            'sshExecutable': 'test-ssh-executable',
            'sshRemote': 'test-ssh-remote',
            'remoteInstallPath': 'test-remote-install-path',
            'displaySizeMillimeters': [1, 2],
            'devicePixelRatio': 1.23,
            'dummyDisplaySize': [3, 4],
          },
        ],
      },
    );
  });

  test('listing configs', () {
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id-2',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );

    expect(
      config.getDevices(),
      unorderedEquals(
        [
          DeviceConfigEntry(
            id: 'test-id',
            sshExecutable: 'test-ssh-executable',
            sshRemote: 'test-ssh-remote',
            remoteInstallPath: 'test-remote-install-path',
            displaySizeMillimeters: (1, 2),
            devicePixelRatio: 1.23,
            useDummyDisplay: false,
            dummyDisplaySize: (3, 4),
          ),
          DeviceConfigEntry(
            id: 'test-id-2',
            sshExecutable: 'test-ssh-executable',
            sshRemote: 'test-ssh-remote',
            remoteInstallPath: 'test-remote-install-path',
            displaySizeMillimeters: (1, 2),
            devicePixelRatio: 1.23,
            useDummyDisplay: false,
            dummyDisplaySize: (3, 4),
          ),
        ],
      ),
    );
  });

  test('contains device', () {
    config.addDevice(
      DeviceConfigEntry(
        id: 'test-id',
        sshExecutable: 'test-ssh-executable',
        sshRemote: 'test-ssh-remote',
        remoteInstallPath: 'test-remote-install-path',
        displaySizeMillimeters: (1, 2),
        devicePixelRatio: 1.23,
        useDummyDisplay: false,
        dummyDisplaySize: (3, 4),
      ),
    );

    expect(config.containsDevice('test-id'), isTrue);
    expect(config.containsDevice('non-existing-id'), isFalse);
  });
}
