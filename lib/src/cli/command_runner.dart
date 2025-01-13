// ignore_for_file: avoid_print, implementation_imports

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

class FlutterpiToolCommandRunner extends CommandRunner<void>
    implements FlutterCommandRunner {
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

    argParser.addOption(
      FlutterGlobalOptions.kLocalWebSDKOption,
      hide: !verboseHelp,
      help:
          'Name of a build output within the engine out directory, if you are building Flutter locally.\n'
          'Use this to select a specific version of the web sdk if you have built multiple engine targets.\n'
          'This path is relative to "--local-engine-src-path" (see above).',
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

  @override
  Future<void> run(Iterable<String> args) {
    // This hacky rewriting cmdlines is also done in the upstream flutter tool.

    /// FIXME: This fails when options are specified.
    if (args.singleOrNull == 'devices') {
      args = <String>['devices', 'list'];
    }

    return super.run(args);
  }
}

abstract class FlutterpiCommand extends FlutterCommand
    with FlutterpiCommandMixin {}
