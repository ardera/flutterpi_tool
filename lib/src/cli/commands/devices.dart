import 'package:args/command_runner.dart';
import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';

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

  static void printList(Iterable<Diagnostic> diagnostics, {required Logger logger}) {
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
  String get description => 'Manage flutterpi_tool devices.';

  @override
  String get name => 'devices';

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
        "Unable to locate a development device; please run 'flutter doctor' for "
        'information about installing additional components.',
        exitCode: 1,
      );
    }

    final output = DevicesCommandOutput(
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
      globals.printError('flutterpi_tool device with id $id already exists.');
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

      final hasPermissions = await ssh.remoteUserBelongsToGroups(['video', 'input']);
      if (!hasPermissions) {
        final addGroupsCommand = ssh
            .buildSshCommand(
              interactive: null,
              allocateTTY: true,
              command: r"'sudo usermod -aG video,input $USER'",
            )
            .join(' ');

        diagnostics.add(Diagnostic.fixCommand(
          title: 'The remote user needs permission to use display and input devices.',
          message: 'To add the necessary permissions, run the following command in your terminal.\n'
              'NOTE: This gives any app running as the remote user access to the display and input devices. '
              'If you\'re running untrusted code, consider the security implications.\n',
          command: addGroupsCommand,
        ));
      }
    }

    globals.flutterPiToolConfig.addDevice(DeviceConfigEntry(
      id: id,
      sshExecutable: sshExecutable,
      sshRemote: remote,
      remoteInstallPath: remoteInstallPath,
      displaySizeMillimeters: displaySize,
    ));

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
