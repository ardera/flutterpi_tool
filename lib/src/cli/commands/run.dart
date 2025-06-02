// ignore_for_file: implementation_imports

import 'package:file/file.dart';
import 'package:meta/meta.dart';

import 'package:flutterpi_tool/src/fltool/common.dart' as fltool;
import 'package:flutterpi_tool/src/fltool/context_runner.dart' as fltool;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/artifacts.dart';

class RunCommand extends fltool.RunCommand with FlutterpiCommandMixin {
  RunCommand({bool verboseHelp = false}) {
    usesDeviceManager();
    usesEngineFlavorOption();
    usesDebugSymbolsOption();
    usesLocalFlutterpiExecutableArg(verboseHelp: verboseHelp);
  }

  @protected
  @override
  Future<fltool.DebuggingOptions> createDebuggingOptions(bool webMode) async {
    final buildInfo = await getBuildInfo();

    if (buildInfo.mode.isRelease) {
      return fltool.DebuggingOptions.disabled(buildInfo);
    } else {
      return fltool.DebuggingOptions.enabled(buildInfo);
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
  Future<fltool.FlutterCommandResult> runCommand() async {
    await populateCache();

    FlutterpiArtifacts artifacts = globals.flutterpiArtifacts;
    if (getLocalFlutterpiExecutable() case File file) {
      artifacts = LocalFlutterpiBinaryOverride(
        inner: artifacts,
        flutterpiBinary: file,
      );
    }

    return fltool.runInContext(
      super.runCommand,
      overrides: {
        fltool.Artifacts: () => artifacts,
        FlutterpiArtifacts: () => artifacts,
      },
    );
  }
}
