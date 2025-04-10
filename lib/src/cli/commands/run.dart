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
    return super.runCommand();
  }
}
