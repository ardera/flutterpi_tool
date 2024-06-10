// ignore: implementation_imports
import 'package:flutter_tools/src/commands/run.dart' as fltool;
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutterpi_tool/src/commands/flutterpi_command.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

class RunCommand extends fltool.RunCommand with FlutterpiCommandMixin {
  RunCommand() {
    usesDeviceManager();
    usesEngineFlavorOption();
    usesDebugSymbolsOption();
  }

  @override
  void addBuildModeFlags({
    required bool verboseHelp,
    bool defaultToRelease = true,
    bool excludeDebug = false,
    bool excludeRelease = false,
  }) {
    // noop
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    await populateCache();

    return super.runCommand();
  }
}
