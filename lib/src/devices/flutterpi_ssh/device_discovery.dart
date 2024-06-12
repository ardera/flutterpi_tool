import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';

class FlutterpiSshDeviceDiscovery extends PollingDeviceDiscovery {
  FlutterpiSshDeviceDiscovery({
    required this.sshUtils,
    required this.config,
    required this.logger,
    required this.os,
    required this.cache,
  }) : super('SSH Devices');

  final SshUtils sshUtils;
  final FlutterPiToolConfig config;
  final Logger logger;
  final MoreOperatingSystemUtils os;
  final FlutterpiCache cache;

  @override
  bool get canListAnything => true;

  Future<Device?> getDeviceIfReachable({Duration? timeout, required DeviceConfigEntry configEntry}) async {
    final sshUtils = SshUtils(
      processUtils: this.sshUtils.processUtils,
      defaultRemote: configEntry.sshRemote,
      sshExecutable: configEntry.sshExecutable ?? this.sshUtils.sshExecutable,
    );

    if (!await sshUtils.tryConnect(timeout: timeout)) {
      return null;
    }

    return FlutterpiSshDevice(
      id: configEntry.id,
      name: configEntry.id,
      sshUtils: sshUtils,
      remoteInstallPath: configEntry.remoteInstallPath,
      logger: logger,
      cache: cache,
      os: os,
      explicitDisplaySizeMillimeters: configEntry.displaySizeMillimeters,
      explicitDevicePixelRatio: null,
    );
  }

  @override
  Future<List<Device>> pollingGetDevices({Duration? timeout}) async {
    timeout ??= Duration(seconds: 5);

    final entries = config.getDevices();

    final devices = await Future.wait([
      for (final entry in entries) getDeviceIfReachable(configEntry: entry, timeout: timeout),
    ]);

    devices.removeWhere((element) => element == null);

    return List<Device>.from(devices);
  }

  @override
  bool get supportsPlatform => true;

  @override
  List<String> get wellKnownIds => const [];
}
