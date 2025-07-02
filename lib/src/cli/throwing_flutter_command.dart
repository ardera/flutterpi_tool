import 'package:flutterpi_tool/src/fltool/common.dart';

class ThrowingFlutterCommand implements FlutterCommand {
  @override
  noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Method ${invocation.memberName} is not supported in flutterpi_tool.',
    );
  }
}
