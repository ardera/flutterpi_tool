// ignore_for_file: avoid_print, implementation_imports

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/commands/flutterpi_command.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

class FlutterpiToolCommandRunner extends CommandRunner<void> implements FlutterCommandRunner {
  FlutterpiToolCommandRunner({bool verboseHelp = false})
      : super(
          'flutterpi_tool',
          'A tool to make development & distribution of flutter-pi apps easier.',
          usageLineLength: 120,
        ) {
    argParser.addOption(
      FlutterGlobalOptions.kPackagesOption,
      hide: true,
      help: 'Path to your "package_config.json" file.',
    );

    argParser.addOption(
      FlutterGlobalOptions.kDeviceIdOption,
      abbr: 'd',
      help: 'Target device id or name (prefixes allowed).',
    );
  }

  @override
  String get usageFooter => '';

  @override
  List<Directory> getRepoPackages() {
    throw UnimplementedError();
  }

  @override
  List<String> getRepoRoots() {
    throw UnimplementedError();
  }

  @override
  void addCommand(Command<void> command) {
    if (command.name != 'help' && command is! FlutterpiCommandMixin) {
      throw ArgumentError('Command is not a FlutterCommand: $command');
    }

    super.addCommand(command);
  }
}

abstract class FlutterpiCommand extends FlutterCommand with FlutterpiCommandMixin {}
