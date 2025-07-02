// ignore_for_file: avoid_print, implementation_imports

import 'package:args/command_runner.dart';
import 'package:args/src/arg_parser.dart';
import 'package:file/file.dart';
import 'package:meta/meta.dart';

import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/cli/throwing_flutter_command.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

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

    argParser.addFlag(
      FlutterGlobalOptions.kPrintDtd,
      negatable: false,
      help:
          'Print the address of the Dart Tooling Daemon, if one is hosted by the Flutter CLI.',
      hide: !verboseHelp,
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

class ExtensibleFlutterCommandImpl extends ThrowingFlutterCommand
    implements ExtensibleCommandBase {
  ExtensibleFlutterCommandImpl() {
    addArgs(argParser);
    addContextOverrides(overrides);
  }

  @override
  late final ArgParser argParser = ArgParser();

  @protected
  final Map<Type, Function()> overrides = <Type, Function()>{};

  @override
  void validateNonOptionArgs() {
    if (argResults!.rest.isNotEmpty) {
      throw UsageException(
        'Too many non-option arguments specified: ${argResults!.rest}',
        usage,
      );
    }
  }

  @override
  void validateArgs() {}

  @override
  Future<void> run() {
    final startTime = globals.systemClock.now();

    return context.run<void>(
      name: 'command',
      overrides: {FlutterCommand: () => this},
      body: () async {
        try {
          await verifyThenRunCommand(null);
        } finally {
          final endTime = globals.systemClock.now();
          globals.printTrace(
            globals.userMessages.flutterElapsedTime(
              name,
              getElapsedAsMilliseconds(endTime.difference(startTime)),
            ),
          );
        }
      },
    );
  }

  @override
  bool boolArg(String name, {bool global = false}) {
    return (global ? globalResults : argResults)!.flag(name);
  }

  @override
  String? stringArg(String name, {bool global = false}) {
    return (global ? globalResults : argResults)!.option(name);
  }

  @override
  List<String> stringsArg(String name, {bool global = false}) {
    return (global ? globalResults : argResults)!.multiOption(name);
  }
}
