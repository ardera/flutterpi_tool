// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:io' as io;
import 'package:flutterpi_tool/src/fltool/common.dart';

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
