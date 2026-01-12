// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'package:args/command_runner.dart';
import 'package:flutterpi_tool/src/context.dart';
import 'package:flutterpi_tool/src/shutdown_hooks.dart';
import 'package:meta/meta.dart';

import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/cli/commands/build.dart';
import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/cli/commands/devices.dart';
import 'package:flutterpi_tool/src/cli/commands/precache.dart';
import 'package:flutterpi_tool/src/cli/commands/run.dart';
import 'package:flutterpi_tool/src/cli/commands/test.dart';

import 'package:flutterpi_tool/src/fltool/common.dart' as fltool;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

@visibleForTesting
FlutterpiToolCommandRunner createFlutterpiCommandRunner({
  bool verboseHelp = false,
}) {
  final runner = FlutterpiToolCommandRunner(verboseHelp: verboseHelp);

  runner.addCommand(BuildCommand(verboseHelp: verboseHelp));
  runner.addCommand(PrecacheCommand());
  runner.addCommand(DevicesCommand(verboseHelp: verboseHelp));
  runner.addCommand(RunCommand(verboseHelp: verboseHelp));
  runner.addCommand(TestCommand());

  runner.argParser
    ..addSeparator('Other options')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.');

  return runner;
}

// Helper to extract option value from args
String? _extractOption(List<String> args, String optionName) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--$optionName' && i + 1 < args.length) {
      return args[i + 1];
    }
    if (arg.startsWith('--$optionName=')) {
      return arg.substring('--$optionName='.length);
    }
  }
  return null;
}

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

  // Parse github-artifacts options early (before context is set up)
  final githubArtifactsRepo = _extractOption(args, 'github-artifacts-repo');
  final githubArtifactsRunId = _extractOption(args, 'github-artifacts-runid');
  final githubArtifactsEngineVersion =
      _extractOption(args, 'github-artifacts-engine-version');
  final githubArtifactsAuthToken =
      _extractOption(args, 'github-artifacts-auth-token');

  final runner = createFlutterpiCommandRunner(verboseHelp: verboseHelp);

  fltool.Cache.flutterRoot = await getFlutterRoot();

  await runInContext(
    () async {
      try {
        await runner.run(args);

        await exitWithHooks(
          0,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      } on fltool.ToolExit catch (e) {
        if (e.message != null) {
          globals.printError(e.message!);
        }

        await exitWithHooks(
          0,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      } on UsageException catch (e) {
        globals.printError(e.message);
        globals.printStatus(e.usage);

        await exitWithHooks(
          0,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      }
    },
    verbose: verbose,
    githubArtifactsRepo: githubArtifactsRepo,
    githubArtifactsRunId: githubArtifactsRunId,
    githubArtifactsEngineVersion: githubArtifactsEngineVersion,
    githubArtifactsAuthToken: githubArtifactsAuthToken,
  );
}
