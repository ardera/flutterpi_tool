import 'dart:async';
import 'dart:io' as io;

import 'package:flutterpi_tool/src/application_package_factory.dart';
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/devices/device_manager.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';
import 'package:unified_analytics/unified_analytics.dart';
import 'package:http/io_client.dart' as http;

import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;
import 'package:flutterpi_tool/src/github.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';

// ignore: implementation_imports
import 'package:flutter_tools/src/context_runner.dart' as fl;

Future<V> runInContext<V>(
  FutureOr<V> Function() fn, {
  bool verbose = false,
}) async {
  return await fl.runInContext(
    fn,
    overrides: {
      Analytics: () => const NoOpAnalytics(),
      fl.TemplateRenderer: () => const fl.MustacheTemplateRenderer(),
      fl.Cache: () => FlutterpiCache(
            hooks: globals.shutdownHooks,
            logger: globals.logger,
            fileSystem: globals.fs,
            platform: globals.platform,
            osUtils: globals.os as MoreOperatingSystemUtils,
            projectFactory: globals.projectFactory,
            processManager: globals.processManager,
            github: MyGithub.caching(
              httpClient: http.IOClient(
                globals.httpClientFactory?.call() ?? io.HttpClient(),
              ),
            ),
          ),
      fl.OperatingSystemUtils: () => MoreOperatingSystemUtils(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            processManager: globals.processManager,
          ),
      fl.Logger: () {
        final f = fl.LoggerFactory(
          outputPreferences: globals.outputPreferences,
          terminal: globals.terminal,
          stdio: globals.stdio,
        );

        return f.createLogger(
          daemon: false,
          machine: false,
          verbose: verbose,
          prefixedErrors: false,
          windows: globals.platform.isWindows,
        );
      },
      fl.Artifacts: () => CachedFlutterpiArtifacts(
            inner: fl.CachedArtifacts(
              fileSystem: globals.fs,
              platform: globals.platform,
              cache: globals.cache,
              operatingSystemUtils: globals.os,
            ),
            cache: globals.flutterpiCache,
          ),
      fl.Usage: () => fl.DisabledUsage(),
      FlutterPiToolConfig: () => FlutterPiToolConfig(
            fs: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
          ),
      fl.BuildTargets: () => const fl.BuildTargetsImpl(),
      fl.ApplicationPackageFactory: () => FlutterpiApplicationPackageFactory(),
      fl.DeviceManager: () => FlutterpiToolDeviceManager(
            logger: globals.logger,
            platform: globals.platform,
            operatingSystemUtils: globals.os as MoreOperatingSystemUtils,
            sshUtils: globals.sshUtils,
            flutterpiToolConfig: globals.flutterPiToolConfig,
          ),
      AppBuilder: () => AppBuilder(
            operatingSystemUtils: globals.moreOs,
            buildSystem: globals.buildSystem,
          ),
      SshUtils: () => SshUtils(
            processUtils: globals.processUtils,
            defaultRemote: '',
          )
    },
  );
}
