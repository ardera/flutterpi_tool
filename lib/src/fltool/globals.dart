export 'package:flutter_tools/src/globals.dart';

// ignore: implementation_imports
import 'package:flutter_tools/src/base/context.dart' show context;
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';

FlutterPiToolConfig get flutterPiToolConfig =>
    context.get<FlutterPiToolConfig>()!;
FlutterpiCache get flutterpiCache => context.get<FlutterpiCache>()!;

FlutterpiArtifacts get flutterpiArtifacts => context.get<FlutterpiArtifacts>()!;
MoreOperatingSystemUtils get moreOs => context.get<MoreOperatingSystemUtils>()!;
