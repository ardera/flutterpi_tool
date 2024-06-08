import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/device/ssh_device_discovery.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/flutterpi_config.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:flutterpi_tool/src/device/ssh_utils.dart';

class FlutterpiToolDeviceManager extends DeviceManager {
  FlutterpiToolDeviceManager({
    required super.logger,
    required Platform platform,
    required FlutterpiCache cache,
    required MoreOperatingSystemUtils operatingSystemUtils,
    required SshUtils sshUtils,
    required FlutterPiToolConfig flutterpiToolConfig,
  }) : deviceDiscoverers = <DeviceDiscovery>[
          SshDeviceDiscovery(
            sshUtils: sshUtils,
            logger: logger,
            config: flutterpiToolConfig,
            os: operatingSystemUtils,
            cache: cache,
          ),
        ];

  @override
  final List<DeviceDiscovery> deviceDiscoverers;
}
