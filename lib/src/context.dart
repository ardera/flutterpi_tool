import 'dart:async';
import 'dart:io' as io;

import 'package:github/github.dart' as gh;
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

/// Raw command-line arguments, set by main() before context initialization.
List<String> rawCommandLineArgs = [];

/// Parse raw command-line arguments for --github-artifacts-runid and related options.
_WorkflowArgs? _parseWorkflowArgs(List<String> args) {
  String? runId;
  String? repo;
  String? authToken;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--github-artifacts-runid=')) {
      runId = arg.substring('--github-artifacts-runid='.length);
    } else if (arg == '--github-artifacts-runid' && i + 1 < args.length) {
      runId = args[++i];
    } else if (arg.startsWith('--github-artifacts-repo=')) {
      repo = arg.substring('--github-artifacts-repo='.length);
    } else if (arg == '--github-artifacts-repo' && i + 1 < args.length) {
      repo = args[++i];
    } else if (arg.startsWith('--github-artifacts-auth-token=')) {
      authToken = arg.substring('--github-artifacts-auth-token='.length);
    } else if (arg == '--github-artifacts-auth-token' && i + 1 < args.length) {
      authToken = args[++i];
    }
  }
  if (runId == null) return null;
  return _WorkflowArgs(runId: runId, repo: repo, authToken: authToken);
}

class _WorkflowArgs {
  final String runId;
  final String? repo;
  final String? authToken;
  _WorkflowArgs({required this.runId, this.repo, this.authToken});
}

Future<V> runInContext<V>(
  FutureOr<V> Function() fn, {
  bool verbose = false,
}) async {
  return await fl.runInContext(
    fn,
    overrides: {
      Analytics: () => const NoOpAnalytics(),
      fl.TemplateRenderer: () => const fl.MustacheTemplateRenderer(),
      fl.Cache: () {
        final workflowArgs = _parseWorkflowArgs(rawCommandLineArgs);
        final httpClient = http.IOClient(
          globals.httpClientFactory?.call() ?? io.HttpClient(),
        );
        final String? token = workflowArgs?.authToken ??
            globals.platform.environment['GITHUB_TOKEN'];
        final github = MyGithub.caching(
          httpClient: httpClient,
          auth: token != null ? gh.Authentication.bearerToken(token) : null,
        );
        if (workflowArgs != null) {
          return FlutterpiCache.fromWorkflow(
            hooks: globals.shutdownHooks,
            logger: globals.logger,
            fileSystem: globals.fs,
            platform: globals.platform,
            osUtils: globals.os as MoreOperatingSystemUtils,
            projectFactory: globals.projectFactory,
            processManager: globals.processManager,
            repo: workflowArgs.repo != null
                ? gh.RepositorySlug.full(workflowArgs.repo!)
                : null,
            runId: workflowArgs.runId,
            github: github,
          );
        }
        return FlutterpiCache(
          hooks: globals.shutdownHooks,
          logger: globals.logger,
          fileSystem: globals.fs,
          platform: globals.platform,
          osUtils: globals.os as MoreOperatingSystemUtils,
          projectFactory: globals.projectFactory,
          processManager: globals.processManager,
          github: github,
        );
      },
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
          widgetPreviews: false,
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
          ),
      fl.FlutterHookRunner: () => fl.FlutterHookRunnerNative(),
    },
  );
}
