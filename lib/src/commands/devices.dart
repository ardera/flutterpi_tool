import 'package:args/command_runner.dart';
import 'package:flutterpi_tool/src/commands/command_runner.dart';
import 'package:flutterpi_tool/src/device/ssh_device.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/flutterpi_config.dart';

mixin DevicesCommandBase on FlutterpiCommand {
  void usesDeviceIdArg({bool mandatory = true}) {}

  String getDeviceIdArg() {
    switch (argResults!.rest) {
      case [String id]:
        return id;
      case [String _, ...]:
        throw UsageException('Too many non-option arguments specified: ${argResults!.rest.skip(1)}', usage);
      case []:
        throw UsageException('Expected device id as non-option arg.', usage);
      default:
        throw StateError('Unexpected non-option argument list: ${argResults!.rest}');
    }
  }
}

class DevicesCommand extends FlutterpiCommand {
  DevicesCommand({bool verboseHelp = false}) {
    addSubcommand(DevicesAddCommand());
    addSubcommand(DevicesRemoveCommand());
    addSubcommand(DevicesListCommand());
  }

  @override
  String get description => 'Manage flutterpi_tool devices.';

  @override
  String get name => 'devices';

  @override
  Future<FlutterCommandResult> runCommand() {
    throw UnimplementedError();
  }
}

class DevicesListCommand extends FlutterpiCommand {
  @override
  String get description => 'List flutterpi_tool device.';

  @override
  String get name => 'list';

  @override
  Future<FlutterCommandResult> runCommand() {
    throw UnimplementedError();
  }
}

class DevicesAddCommand extends FlutterpiCommand with DevicesCommandBase {
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
      'ssh-target',
      help: 'The SSH target, with or without the username prefix. '
          'If this is not specified it\'s assumed this is equivalent to the device id. '
          'Example: root@embedded-board',
      valueHelp: '[user@]hostname',
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

    usesDeviceIdArg();
  }

  @override
  String get description => 'Add a new flutterpi_tool device.';

  @override
  String get name => 'add';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final id = getDeviceIdArg();

    final type = stringArg('type');
    if (type != 'ssh') {
      throw UsageException('Unsupported device type: $type', usage);
    }

    final sshTarget = stringArg('ssh-target') ?? id;

    final sshExecutable = stringArg('ssh-executable');

    final remoteInstallPath = stringArg('remote-install-path');

    final force = boolArg('force');

    final flutterpiToolConfig = globals.flutterPiToolConfig;
    if (flutterpiToolConfig.containsDevice(id)) {
      globals.printError('flutterpi_tool device with id $id already exists.');
      return FlutterCommandResult.fail();
    }

    if (!force) {
      final ssh = SshUtils(
        processUtils: globals.processUtils,
        sshExecutable: sshExecutable ?? 'ssh',
        defaultRemote: sshTarget,
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
    }

    globals.flutterPiToolConfig.addDevice(
      DeviceConfigEntry(
        id: id,
        sshExecutable: sshExecutable,
        sshRemote: sshTarget,
        remoteInstallPath: remoteInstallPath,
      ),
    );

    return FlutterCommandResult.success();
  }
}

class DevicesRemoveCommand extends FlutterpiCommand with DevicesCommandBase {
  DevicesRemoveCommand() {
    usesDeviceIdArg();
  }

  @override
  String get description => 'Remove a flutterpi_tool device.';

  @override
  String get name => 'remove';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final id = getDeviceIdArg();

    final flutterpiToolConfig = globals.flutterPiToolConfig;

    if (!flutterpiToolConfig.containsDevice(id)) {
      globals.printError('No flutterpi_tool device with id $id found.');
      return FlutterCommandResult.fail();
    }

    flutterpiToolConfig.removeDevice(id);
    return FlutterCommandResult.success();
  }
}
