// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:io' as io;
import 'package:args/command_runner.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/commands/build_bundle.dart';
import 'package:flutterpi_tool/src/commands/command_runner.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/context_runner.dart' as fltool;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/more_os_utils.dart';

Future<void> main(List<String> args) async {
  final verbose = args.contains('-v') || args.contains('--verbose') || args.contains('-vv');
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

Future<T> runWithContext<T>({
  required FutureOr<T> Function() runner,
  FlutterpiTargetPlatform? target,
  required FlutterpiCache Function() cacheFactory,
  bool verbose = false,
}) async {
  return fltool.runInContext(
    runner,
    overrides: {
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      Cache: cacheFactory,
      OperatingSystemUtils: () => MoreOperatingSystemUtils(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            processManager: globals.processManager,
          ),
      Logger: () {
        final factory = LoggerFactory(
          outputPreferences: globals.outputPreferences,
          terminal: globals.terminal,
          stdio: globals.stdio,
        );

        return factory.createLogger(
          daemon: false,
          machine: false,
          verbose: verbose,
          prefixedErrors: false,
          windows: globals.platform.isWindows,
        );
      },
      Artifacts: () => CachedArtifacts(
            fileSystem: globals.fs,
            platform: globals.platform,
            cache: globals.cache,
            operatingSystemUtils: globals.os,
          ),
      Usage: () => DisabledUsage()
    },
  );
}

Future<void> exitWithHooks(
  int code, {
  required ShutdownHooks shutdownHooks,
  required Logger logger,
}) async {
  // Run shutdown hooks before flushing logs
  await shutdownHooks.runShutdownHooks(logger);

  final completer = Completer<void>();

  // Give the task / timer queue one cycle through before we hard exit.
  Timer.run(() {
    try {
      logger.printTrace('exiting with code $code');
      io.exit(code);
    } catch (error, stackTrace) {
      // ignore: avoid_catches_without_on_clauses
      completer.completeError(error, stackTrace);
    }
  });

  return completer.future;
}
