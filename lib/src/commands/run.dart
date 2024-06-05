import 'package:flutterpi_tool/src/fltool/common.dart';

class RunCommand extends FlutterCommand {
  @override
  String get description => 'Runs an app on a remote device.';

  @override
  String get name => 'run';

  @override
  Future<FlutterCommandResult> runCommand() {
    throw UnimplementedError();
  }
}