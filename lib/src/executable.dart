// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:io' as io;
import 'package:args/command_runner.dart';
import 'package:flutterpi_tool/src/cli/commands/build.dart';
import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/cli/commands/devices.dart';
import 'package:flutterpi_tool/src/cli/commands/precache.dart';
import 'package:flutterpi_tool/src/cli/commands/run.dart';
import 'package:flutterpi_tool/src/cli/commands/test.dart';

Future<void> main(List<String> args) async {
  final verbose =
      args.contains('-v') || args.contains('--verbose') || args.contains('-vv');
  final powershellHelpIndex = args.indexOf('-?');
  if (powershellHelpIndex != -1) {
    args[powershellHelpIndex] = '-h';
  }

  final help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final verboseHelp = help && verbose;

  final runner = FlutterpiToolCommandRunner(verboseHelp: verboseHelp);

  runner.addCommand(BuildCommand(verboseHelp: verboseHelp));
  runner.addCommand(PrecacheCommand(verboseHelp: verboseHelp));
  runner.addCommand(DevicesCommand(verboseHelp: verboseHelp));
  runner.addCommand(RunCommand(verboseHelp: verboseHelp));
  runner.addCommand(TestCommand());

  runner.argParser
    ..addSeparator('Other options')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.');

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    print(e);
    io.exit(1);
  }
}
