// ignore: implementation_imports
import 'package:flutter_tools/src/commands/run.dart' as fltool;
import 'package:flutterpi_tool/src/commands/flutterpi_command.dart';

class RunCommand extends fltool.RunCommand with FlutterpiCommandMixin {}
