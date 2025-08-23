import 'package:flutterpi_tool/src/devices/flutterpi_ssh/device_discovery.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';

class FlutterpiToolDeviceManager extends DeviceManager {
  FlutterpiToolDeviceManager({
    required super.logger,
    required Platform platform,
    required MoreOperatingSystemUtils operatingSystemUtils,
    required SshUtils sshUtils,
    required FlutterPiToolConfig flutterpiToolConfig,
    this.specifiedDeviceId,
  }) : deviceDiscoverers = <DeviceDiscovery>[
          FlutterpiSshDeviceDiscovery(
            sshUtils: sshUtils,
            logger: logger,
            config: flutterpiToolConfig,
            os: operatingSystemUtils,
          ),
        ];
  @override
  final List<DeviceDiscovery> deviceDiscoverers;

  @override
  String? specifiedDeviceId;
}
