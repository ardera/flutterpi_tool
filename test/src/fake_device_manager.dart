import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:test/fake.dart';

class FakeDeviceManager implements fl.DeviceManager {
  var devices = <fl.Device>[];

  @override
  String? specifiedDeviceId;

  @override
  bool get hasSpecifiedDeviceId => specifiedDeviceId != null;

  @override
  bool get hasSpecifiedAllDevices => specifiedDeviceId == null;

  @override
  Future<List<fl.Device>> getAllDevices({
    fl.DeviceDiscoveryFilter? filter,
  }) async {
    return await filter?.filterDevices(devices) ?? devices;
  }

  @override
  Future<List<fl.Device>> refreshAllDevices({
    Duration? timeout,
    fl.DeviceDiscoveryFilter? filter,
  }) async {
    return await getAllDevices(filter: filter);
  }

  @override
  Future<List<fl.Device>> refreshExtendedWirelessDeviceDiscoverers({
    Duration? timeout,
    fl.DeviceDiscoveryFilter? filter,
  }) async {
    return await getAllDevices(filter: filter);
  }

  @override
  Future<List<fl.Device>> getDevicesById(
    String deviceId, {
    fl.DeviceDiscoveryFilter? filter,
    bool waitForDeviceToConnect = false,
  }) async {
    final devices = await getAllDevices(filter: filter);
    return devices.where((device) {
      return device.id == deviceId || device.id.startsWith(deviceId);
    }).toList();
  }

  @override
  Future<List<fl.Device>> getDevices({
    fl.DeviceDiscoveryFilter? filter,
    bool waitForDeviceToConnect = false,
  }) {
    return hasSpecifiedDeviceId
        ? getDevicesById(specifiedDeviceId!, filter: filter)
        : getAllDevices(filter: filter);
  }

  @override
  bool get canListAnything => true;

  @override
  Future<List<String>> getDeviceDiagnostics() async => <String>[];

  @override
  List<fl.DeviceDiscovery> get deviceDiscoverers => <fl.DeviceDiscovery>[];

  @override
  fl.DeviceDiscoverySupportFilter deviceSupportFilter({
    bool includeDevicesUnsupportedByProject = false,
    fl.FlutterProject? flutterProject,
  }) {
    fl.FlutterProject? flutterProject;
    if (!includeDevicesUnsupportedByProject) {
      flutterProject = fl.FlutterProject.current();
    }
    if (hasSpecifiedAllDevices) {
      return fl.DeviceDiscoverySupportFilter
          .excludeDevicesUnsupportedByFlutterOrProjectOrAll(
        flutterProject: flutterProject,
      );
    } else if (!hasSpecifiedDeviceId) {
      return fl.DeviceDiscoverySupportFilter
          .excludeDevicesUnsupportedByFlutterOrProject(
        flutterProject: flutterProject,
      );
    } else {
      return fl.DeviceDiscoverySupportFilter
          .excludeDevicesUnsupportedByFlutter();
    }
  }

  @override
  fl.Device? getSingleEphemeralDevice(List<fl.Device> devices) => null;
}

class FakeFilter extends Fake implements fl.DeviceDiscoverySupportFilter {
  FakeFilter();
}
