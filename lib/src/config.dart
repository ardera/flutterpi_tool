import 'package:file/file.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

class DeviceConfigEntry {
  const DeviceConfigEntry({
    required this.id,
    required this.sshExecutable,
    required this.sshRemote,
    required this.remoteInstallPath,
    this.displaySizeMillimeters,
    this.devicePixelRatio,
    this.useDummyDisplay,
    this.dummyDisplaySize,
  });

  final String id;
  final String? sshExecutable;
  final String sshRemote;
  final String? remoteInstallPath;
  final (int, int)? displaySizeMillimeters;
  final double? devicePixelRatio;
  final bool? useDummyDisplay;
  final (int, int)? dummyDisplaySize;

  static DeviceConfigEntry fromMap(Map<String, dynamic> map) {
    return DeviceConfigEntry(
      id: map['id'] as String,
      sshExecutable: map['sshExecutable'] as String?,
      sshRemote: map['sshRemote'] as String,
      remoteInstallPath: map['remoteInstallPath'] as String?,
      displaySizeMillimeters: switch (map['displaySizeMillimeters']) {
        [num width, num height] => (width.round(), height.round()),
        _ => null,
      },
      devicePixelRatio: (map['devicePixelRatio'] as num?)?.toDouble(),
      useDummyDisplay: map['useDummyDisplay'] as bool?,
      dummyDisplaySize: switch (map['dummyDisplaySize']) {
        [num width, num height] => (width.round(), height.round()),
        _ => null,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'sshExecutable': sshExecutable,
      'sshRemote': sshRemote,
      'remoteInstallPath': remoteInstallPath,
      if (displaySizeMillimeters case (final width, final height))
        'displaySizeMillimeters': [width, height],
      if (devicePixelRatio case int devicePixelRatio)
        'devicePixelRatio': devicePixelRatio,
      if (useDummyDisplay case bool useDummyDisplay)
        'useDummyDisplay': useDummyDisplay,
      if (dummyDisplaySize case (final width, final height))
        'dummyDisplaySize': [width, height],
    };
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != DeviceConfigEntry) {
      return false;
    }

    final DeviceConfigEntry otherEntry = other as DeviceConfigEntry;

    return id == otherEntry.id &&
        sshExecutable == otherEntry.sshExecutable &&
        sshRemote == otherEntry.sshRemote &&
        remoteInstallPath == otherEntry.remoteInstallPath &&
        displaySizeMillimeters == otherEntry.displaySizeMillimeters &&
        devicePixelRatio == otherEntry.devicePixelRatio &&
        useDummyDisplay == otherEntry.useDummyDisplay &&
        dummyDisplaySize == otherEntry.dummyDisplaySize;
  }

  @override
  int get hashCode => Object.hash(
        id,
        sshExecutable,
        sshRemote,
        remoteInstallPath,
        displaySizeMillimeters,
        devicePixelRatio,
        useDummyDisplay,
        dummyDisplaySize,
      );
}

class FlutterPiToolConfig {
  FlutterPiToolConfig({
    required this.fs,
    required this.logger,
    required this.platform,
  }) : _config = Config(
          'flutterpi_tool_config',
          fileSystem: fs,
          logger: logger,
          platform: platform,
        );

  final FileSystem fs;
  final Logger logger;
  final Platform platform;
  final Config _config;

  List<DeviceConfigEntry> getDevices() {
    final entries = _config.getValue('devices');

    switch (entries) {
      case List entries:
        final devices = entries.whereType<Map>().map((entry) {
          return DeviceConfigEntry.fromMap(entry.cast<String, dynamic>());
        }).toList();

        return devices;
      default:
        return [];
    }
  }

  void _setDevices(List<DeviceConfigEntry> devices) {
    _config.setValue('devices', devices.map((e) => e.toMap()).toList());
  }

  void addDevice(DeviceConfigEntry device) {
    _setDevices([...getDevices(), device]);
  }

  void removeDevice(String id) {
    final devices = getDevices();

    devices.removeWhere((entry) => entry.id == id);

    _setDevices(devices);
  }

  bool containsDevice(String id) {
    return getDevices().any((element) => element.id == id);
  }
}
