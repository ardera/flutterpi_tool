import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';

String pluralize(String word, int count) => count == 1 ? word : '${word}s';

class FlutterpiToolDevicesCommandOutput {
  factory FlutterpiToolDevicesCommandOutput({
    required Platform platform,
    required Logger logger,
    DeviceManager? deviceManager,
    Duration? deviceDiscoveryTimeout,
    DeviceConnectionInterface? deviceConnectionInterface,
  }) {
    if (platform.isMacOS) {
      return FlutterpiToolDevicesCommandOutputWithExtendedWirelessDeviceDiscovery(
        logger: logger,
        deviceManager: deviceManager,
        deviceDiscoveryTimeout: deviceDiscoveryTimeout,
        deviceConnectionInterface: deviceConnectionInterface,
      );
    }
    return FlutterpiToolDevicesCommandOutput._private(
      logger: logger,
      deviceManager: deviceManager,
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      deviceConnectionInterface: deviceConnectionInterface,
    );
  }

  FlutterpiToolDevicesCommandOutput._private({
    required Logger logger,
    required DeviceManager? deviceManager,
    required this.deviceDiscoveryTimeout,
    required this.deviceConnectionInterface,
  })  : _deviceManager = deviceManager,
        _logger = logger;

  final DeviceManager? _deviceManager;
  final Logger _logger;
  final Duration? deviceDiscoveryTimeout;
  final DeviceConnectionInterface? deviceConnectionInterface;

  bool get _includeAttachedDevices =>
      deviceConnectionInterface == null ||
      deviceConnectionInterface == DeviceConnectionInterface.attached;

  bool get _includeWirelessDevices =>
      deviceConnectionInterface == null ||
      deviceConnectionInterface == DeviceConnectionInterface.wireless;

  Future<List<Device>> _getAttachedDevices(DeviceManager deviceManager) async {
    if (!_includeAttachedDevices) {
      return <Device>[];
    }
    return deviceManager.getAllDevices(
      filter: DeviceDiscoveryFilter(
        deviceConnectionInterface: DeviceConnectionInterface.attached,
      ),
    );
  }

  Future<List<Device>> _getWirelessDevices(DeviceManager deviceManager) async {
    if (!_includeWirelessDevices) {
      return <Device>[];
    }
    return deviceManager.getAllDevices(
      filter: DeviceDiscoveryFilter(
        deviceConnectionInterface: DeviceConnectionInterface.wireless,
      ),
    );
  }

  Future<void> findAndOutputAllTargetDevices({required bool machine}) async {
    List<Device> attachedDevices = <Device>[];
    List<Device> wirelessDevices = <Device>[];
    final DeviceManager? deviceManager = _deviceManager;
    if (deviceManager != null) {
      // Refresh the cache and then get the attached and wireless devices from
      // the cache.
      await deviceManager.refreshAllDevices(timeout: deviceDiscoveryTimeout);
      attachedDevices = await _getAttachedDevices(deviceManager);
      wirelessDevices = await _getWirelessDevices(deviceManager);
    }
    final List<Device> allDevices = attachedDevices + wirelessDevices;

    if (machine) {
      await printDevicesAsJson(allDevices);
      return;
    }

    if (allDevices.isEmpty) {
      _logger.printStatus('No authorized devices detected.');
    } else {
      if (attachedDevices.isNotEmpty) {
        _logger.printStatus(
          'Found ${attachedDevices.length} connected ${pluralize('device', attachedDevices.length)}:',
        );
        await Device.printDevices(attachedDevices, _logger, prefix: '  ');
      }
      if (wirelessDevices.isNotEmpty) {
        if (attachedDevices.isNotEmpty) {
          _logger.printStatus('');
        }
        _logger.printStatus(
          'Found ${wirelessDevices.length} wirelessly connected ${pluralize('device', wirelessDevices.length)}:',
        );
        await Device.printDevices(wirelessDevices, _logger, prefix: '  ');
      }
    }
    await _printDiagnostics(foundAny: allDevices.isNotEmpty);
  }

  Future<void> _printDiagnostics({required bool foundAny}) async {
    final status = StringBuffer();
    status.writeln();

    final diagnostics =
        await _deviceManager?.getDeviceDiagnostics() ?? <String>[];
    if (diagnostics.isNotEmpty) {
      for (final diagnostic in diagnostics) {
        status.writeln(diagnostic);
        status.writeln();
      }
    }
    status.write(
      'If you expected ${foundAny ? 'another' : 'a'} device to be detected, try increasing the time to wait for connected devices by using the "flutterpi_tool devices list" command with the "--${FlutterOptions.kDeviceTimeout}" flag.',
    );
    _logger.printStatus(status.toString());
  }

  Future<void> printDevicesAsJson(List<Device> devices) async {
    _logger.printStatus(
      const JsonEncoder.withIndent('  ')
          .convert(await Future.wait(devices.map((d) => d.toJson()))),
    );
  }
}

const String _checkingForWirelessDevicesMessage =
    'Checking for wireless devices...';
const String _noAttachedCheckForWireless =
    'No devices found yet. Checking for wireless devices...';
const String _noWirelessDevicesFoundMessage = 'No wireless devices were found.';

class FlutterpiToolDevicesCommandOutputWithExtendedWirelessDeviceDiscovery
    extends FlutterpiToolDevicesCommandOutput {
  FlutterpiToolDevicesCommandOutputWithExtendedWirelessDeviceDiscovery({
    required super.logger,
    super.deviceManager,
    super.deviceDiscoveryTimeout,
    super.deviceConnectionInterface,
  }) : super._private();

  @override
  Future<void> findAndOutputAllTargetDevices({required bool machine}) async {
    // When a user defines the timeout or filters to only attached devices,
    // use the super function that does not do longer wireless device discovery.
    if (deviceDiscoveryTimeout != null ||
        deviceConnectionInterface == DeviceConnectionInterface.attached) {
      return super.findAndOutputAllTargetDevices(machine: machine);
    }

    if (machine) {
      final List<Device> devices = await _deviceManager?.refreshAllDevices(
            filter: DeviceDiscoveryFilter(
              deviceConnectionInterface: deviceConnectionInterface,
            ),
            timeout: DeviceManager.minimumWirelessDeviceDiscoveryTimeout,
          ) ??
          <Device>[];
      await printDevicesAsJson(devices);
      return;
    }

    final Future<void>? extendedWirelessDiscovery =
        _deviceManager?.refreshExtendedWirelessDeviceDiscoverers(
      timeout: DeviceManager.minimumWirelessDeviceDiscoveryTimeout,
    );

    List<Device> attachedDevices = <Device>[];
    final DeviceManager? deviceManager = _deviceManager;
    if (deviceManager != null) {
      attachedDevices = await _getAttachedDevices(deviceManager);
    }

    // Number of lines to clear starts at 1 because it's inclusive of the line
    // the cursor is on, which will be blank for this use case.
    int numLinesToClear = 1;

    // Display list of attached devices.
    if (attachedDevices.isNotEmpty) {
      _logger.printStatus(
        'Found ${attachedDevices.length} connected ${pluralize('device', attachedDevices.length)}:',
      );
      await Device.printDevices(attachedDevices, _logger, prefix: '  ');
      _logger.printStatus('');
      numLinesToClear += 1;
    }

    // Display waiting message.
    if (attachedDevices.isEmpty && _includeAttachedDevices) {
      _logger.printStatus(_noAttachedCheckForWireless);
    } else {
      _logger.printStatus(_checkingForWirelessDevicesMessage);
    }
    numLinesToClear += 1;

    final Status waitingStatus = _logger.startSpinner();
    await extendedWirelessDiscovery;
    List<Device> wirelessDevices = <Device>[];
    if (deviceManager != null) {
      wirelessDevices = await _getWirelessDevices(deviceManager);
    }
    waitingStatus.stop();

    final Terminal terminal = _logger.terminal;
    if (_logger.isVerbose && _includeAttachedDevices) {
      // Reprint the attach devices.
      if (attachedDevices.isNotEmpty) {
        _logger.printStatus(
          '\nFound ${attachedDevices.length} connected ${pluralize('device', attachedDevices.length)}:',
        );
        await Device.printDevices(attachedDevices, _logger, prefix: '  ');
      }
    } else if (terminal.supportsColor && terminal is AnsiTerminal) {
      _logger.printStatus(
        terminal.clearLines(numLinesToClear),
        newline: false,
      );
    }

    if (attachedDevices.isNotEmpty || !_logger.terminal.supportsColor) {
      _logger.printStatus('');
    }

    if (wirelessDevices.isEmpty) {
      if (attachedDevices.isEmpty) {
        // No wireless or attached devices were found.
        _logger.printStatus('No authorized devices detected.');
      } else {
        // Attached devices found, wireless devices not found.
        _logger.printStatus(_noWirelessDevicesFoundMessage);
      }
    } else {
      // Display list of wireless devices.
      _logger.printStatus(
        'Found ${wirelessDevices.length} wirelessly connected ${pluralize('device', wirelessDevices.length)}:',
      );
      await Device.printDevices(wirelessDevices, _logger, prefix: '  ');
    }
    await _printDiagnostics(
      foundAny: wirelessDevices.isNotEmpty || attachedDevices.isNotEmpty,
    );
  }
}

// A diagnostic message, reported to the user when a problem is detected.
abstract class Diagnostic {
  const Diagnostic();

  const factory Diagnostic.fixCommand({
    required String title,
    required String message,
    required String command,
  }) = FixCommandDiagnostic;

  String get title;

  void printMessage(Logger logger);

  static void printList(
    Iterable<Diagnostic> diagnostics, {
    required Logger logger,
  }) {
    for (final (index, diagnostic) in diagnostics.indexed) {
      logger.printStatus('${index + 1}. ${diagnostic.title}');
      diagnostic.printMessage(logger);
    }
  }
}

// A diagnostic message that includes a command to fix the issue.
class FixCommandDiagnostic extends Diagnostic {
  const FixCommandDiagnostic({
    required this.title,
    required this.message,
    required this.command,
  });

  @override
  final String title;
  final String message;
  final String command;

  @override
  void printMessage(Logger logger, {int indent = 3}) {
    logger.printStatus(message, indent: indent);
    logger.printStatus(command, indent: indent + 2, emphasis: true);
  }
}

class DevicesCommand extends FlutterpiCommand {
  DevicesCommand({bool verboseHelp = false}) {
    addSubcommand(DevicesAddCommand());
    addSubcommand(DevicesRemoveCommand());
    addSubcommand(DevicesListCommand());
  }

  @override
  String get description => 'List & manage flutterpi_tool devices.';

  @override
  final String category = FlutterCommandCategory.tools;

  @override
  String get name => 'devices';

  @override
  String get invocation =>
      '${runner!.executableName} devices [subcommand] [arguments]';

  @override
  String? get usageFooter =>
      'If no subcommand is specified, the attached devices will be listed.';

  @override
  Future<FlutterCommandResult> runCommand() async {
    throw UnimplementedError();
  }
}

class DevicesListCommand extends FlutterpiCommand {
  DevicesListCommand() {
    usesDeviceTimeoutOption();
    usesDeviceConnectionOption();

    usesDeviceManager();
  }

  @override
  String get description => 'List flutterpi_tool device.';

  @override
  String get name => 'list';

  @override
  Future<FlutterCommandResult> runCommand() async {
    if (globals.doctor?.canListAnything != true) {
      throwToolExit(
        "Unable to locate a development device.",
        exitCode: 1,
      );
    }

    final output = FlutterpiToolDevicesCommandOutput(
      platform: globals.platform,
      logger: globals.logger,
      deviceManager: globals.deviceManager,
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      deviceConnectionInterface: deviceConnectionInterface,
    );

    await output.findAndOutputAllTargetDevices(machine: false);

    return FlutterCommandResult.success();
  }
}

class DevicesAddCommand extends FlutterpiCommand {
  DevicesAddCommand() {
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: ['ssh'],
      help: 'The type of device to add.',
      valueHelp: 'type',
      defaultsTo: 'ssh',
    );

    argParser.addOption(
      'id',
      help: 'The id of the device to be created. If not specified, this is '
          'the hostname part of the [user@]hostname argument.',
      valueHelp: 'id',
    );

    argParser.addOption(
      'ssh-executable',
      help: 'The path to the ssh executable.',
      valueHelp: 'path',
    );

    argParser.addOption(
      'remote-install-path',
      help: 'The path to install flutter apps on the remote device.',
      valueHelp: 'path',
    );

    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Don\'t verify the configured device before adding it.',
    );

    usesDisplaySizeArg();
    usesDummyDisplayArg();
    usesSshRemoteNonOptionArg();
  }

  @override
  String get description => 'Add a new flutterpi_tool device.';

  @override
  String get name => 'add';

  @override
  String get invocation => 'flutterpi_tool devices add <[user@]hostname>';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final remote = sshRemote;

    final id = stringArg('id') ?? sshHostname;

    final type = stringArg('type');
    if (type != 'ssh') {
      throw UsageException('Unsupported device type: $type', usage);
    }

    final sshExecutable = stringArg('ssh-executable');
    final remoteInstallPath = stringArg('remote-install-path');
    final force = boolArg('force');
    final displaySize = this.displaySize;

    final flutterpiToolConfig = globals.flutterPiToolConfig;
    if (flutterpiToolConfig.containsDevice(id)) {
      globals.printError('flutterpi_tool device with id "$id" already exists.');
      return FlutterCommandResult.fail();
    }

    final diagnostics = <Diagnostic>[];

    if (!force) {
      final ssh = SshUtils(
        processUtils: globals.processUtils,
        sshExecutable: sshExecutable ?? 'ssh',
        defaultRemote: remote,
      );

      final connected = await ssh.tryConnect(timeout: Duration(seconds: 5));
      if (!connected) {
        globals.printError(
          'Connecting to device failed. Make sure the device is reachable '
          'and public-key authentication is set up correctly. If you wish to add '
          'the device anyway, use --force.',
        );
        return FlutterCommandResult.fail();
      }

      final hasPermissions =
          await ssh.remoteUserBelongsToGroups(['video', 'input', 'render']);
      if (!hasPermissions) {
        final addGroupsCommand = ssh
            .buildSshCommand(
              interactive: null,
              allocateTTY: true,
              command: r"'sudo usermod -aG video,input,render $USER'",
            )
            .join(' ');

        diagnostics.add(
          Diagnostic.fixCommand(
            title:
                'The remote user needs permission to use display and input devices.',
            message:
                'To add the necessary permissions, run the following command in your terminal.\n'
                'NOTE: This gives any app running as the remote user access to the display, input and render devices. '
                'If you\'re running untrusted code, consider the security implications.\n',
            command: addGroupsCommand,
          ),
        );
      }
    }

    globals.flutterPiToolConfig.addDevice(
      DeviceConfigEntry(
        id: id,
        sshExecutable: sshExecutable,
        sshRemote: remote,
        remoteInstallPath: remoteInstallPath,
        displaySizeMillimeters: displaySize,
        useDummyDisplay: useDummyDisplay,
        dummyDisplaySize: dummyDisplaySize,
      ),
    );

    if (diagnostics.isNotEmpty) {
      globals.printWarning(
        'The device "$id" has been added, but additional steps are necessary to be able to run Flutter apps.',
        color: TerminalColor.yellow,
      );
      Diagnostic.printList(diagnostics, logger: globals.logger);
    } else {
      globals.printStatus('Device "$id" has been added successfully.');
    }

    return FlutterCommandResult.success();
  }
}

class DevicesRemoveCommand extends FlutterpiCommand {
  DevicesRemoveCommand() {
    usesSshRemoteNonOptionArg();
  }

  @override
  String get description => 'Remove a flutterpi_tool device.';

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => ['rm'];

  @override
  Future<FlutterCommandResult> runCommand() async {
    final id = sshHostname;

    final flutterpiToolConfig = globals.flutterPiToolConfig;

    if (!flutterpiToolConfig.containsDevice(id)) {
      globals.printError('No flutterpi_tool device with id "$id" found.');
      return FlutterCommandResult.fail();
    }

    flutterpiToolConfig.removeDevice(id);
    return FlutterCommandResult.success();
  }
}
