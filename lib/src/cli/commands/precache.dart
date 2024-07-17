import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/cli/command_runner.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/more_os_utils.dart';

class PrecacheCommand extends FlutterpiCommand {
  PrecacheCommand({bool verboseHelp = false}) {
    usesCustomCache(verboseHelp: verboseHelp);
  }

  @override
  String get name => 'precache';

  @override
  String get description =>
      'Populate the flutterpi_tool\'s cache of binary artifacts.';

  @override
  final String category = 'Flutter-Pi Tool';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final os = switch (globals.os) {
      MoreOperatingSystemUtils os => os,
      _ => throw StateError(
          'Operating system utils is not an FPiOperatingSystemUtils',
        ),
    };

    final host = switch (os.fpiHostPlatform) {
      FlutterpiHostPlatform.windowsARM64 => FlutterpiHostPlatform.windowsX64,
      FlutterpiHostPlatform.darwinARM64 => FlutterpiHostPlatform.darwinX64,
      FlutterpiHostPlatform other => other
    };

    // update the cached flutter-pi artifacts
    await flutterpiCache.updateAll(
      const {DevelopmentArtifact.universal},
      offline: false,
      host: host,
      flutterpiPlatforms: FlutterpiTargetPlatform.values.toSet(),
      engineFlavors: EngineFlavor.values.toSet(),
      includeDebugSymbols: true,
    );

    return FlutterCommandResult.success();
  }
}
