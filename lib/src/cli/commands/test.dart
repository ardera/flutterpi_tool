import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

class TestCommand extends fl.TestCommand with FlutterpiCommandMixin {
  TestCommand();

  @override
  Future<fl.FlutterCommandResult> runCommand() {
    final specifiedDeviceId = stringArg(
      fl.FlutterGlobalOptions.kDeviceIdOption,
      global: true,
    );
    if (specifiedDeviceId != null) {
      globals.deviceManager?.specifiedDeviceId = specifiedDeviceId;
    }

    return super.runCommand();
  }
}
