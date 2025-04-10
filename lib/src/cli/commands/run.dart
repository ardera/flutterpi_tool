// ignore_for_file: implementation_imports

import 'package:flutter_tools/src/commands/run.dart' as fltool;
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:meta/meta.dart';

class RunCommand extends fltool.RunCommand with FlutterpiCommandMixin {
  RunCommand() {
    usesDeviceManager();
    usesEngineFlavorOption();
    usesDebugSymbolsOption();
    usesRotationOption();
  }

  @protected
  @override
  Future<DebuggingOptions> createDebuggingOptions(bool webMode) async {
    final buildInfo = await getBuildInfo();

    if (buildInfo.mode.isRelease) {
      return DebuggingOptions.disabled(buildInfo);
    } else {
      return DebuggingOptions.enabled(buildInfo);
    }
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
    // Using ! here because [usesRotationOption] only allows 0, 90, 180, and 270.
    final rotation = int.tryParse(stringArg("rotation")!)!;
    print("You asked for a rotation of $rotation");
    throw "All done";
    return super.runCommand();
  }
}
