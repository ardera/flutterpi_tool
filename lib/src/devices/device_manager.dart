import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device_discovery.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';

class FlutterpiToolDeviceManager extends DeviceManager {
  FlutterpiToolDeviceManager({
    required super.logger,
    required Platform platform,
    required FlutterpiCache cache,
    required MoreOperatingSystemUtils operatingSystemUtils,
    required SshUtils sshUtils,
    required FlutterPiToolConfig flutterpiToolConfig,
    required String? deviceId,
  })  : deviceDiscoverers = <DeviceDiscovery>[
          FlutterpiSshDeviceDiscovery(
            sshUtils: sshUtils,
            logger: logger,
            config: flutterpiToolConfig,
            os: operatingSystemUtils,
            cache: cache,
          ),
        ],
        _deviceId = deviceId;

  @override
  final List<DeviceDiscovery> deviceDiscoverers;

  final String? _deviceId;

  @override
  String? get specifiedDeviceId => _deviceId;

  @override
  set specifiedDeviceId(String? deviceId) {
    throw UnsupportedError(
        'Attempted to set device ID on FlutterPiToolDeviceManager.',);
  }
}
