export 'package:flutter_tools/src/globals.dart';

// ignore: implementation_imports
import 'package:flutter_tools/src/base/context.dart' show context;
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/more_os_utils.dart';

FlutterPiToolConfig get flutterPiToolConfig =>
    context.get<FlutterPiToolConfig>()!;
FlutterpiCache get flutterpiCache => context.get<fl.Cache>()! as FlutterpiCache;

FlutterpiArtifacts get flutterpiArtifacts =>
    context.get<fl.Artifacts>()! as FlutterpiArtifacts;
MoreOperatingSystemUtils get moreOs =>
    context.get<fl.OperatingSystemUtils>()! as MoreOperatingSystemUtils;

SshUtils get sshUtils => context.get<SshUtils>()!;

AppBuilder get builder => context.get<AppBuilder>()!;
