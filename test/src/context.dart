// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutterpi_tool/src/build_system/build_app.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/config.dart';
import 'package:flutterpi_tool/src/devices/flutterpi_ssh/ssh_utils.dart';
import 'package:flutterpi_tool/src/github.dart';
import 'package:unified_analytics/unified_analytics.dart';
import 'package:test/test.dart' as test;

import 'package:flutterpi_tool/src/fltool/common.dart' as fltool;
import 'package:flutterpi_tool/src/fltool/globals.dart' as globals;

import '../fake_github.dart';
import 'fake_doctor.dart';
import 'fake_process_manager.dart';
import 'mock_more_os_utils.dart';

Future<V> runInThrowingContext<V>(
  FutureOr<V> Function() body, {
  Map<Type, fltool.Generator> overrides = const {},
}) {
  void fail(Type type) {
    test.fail('Should not access global $type.');
  }

  return fltool.context.run(
    body: body,
    fallbacks: <Type, fltool.Generator>{
      fltool.AnsiTerminal: () => fail(fltool.AnsiTerminal),
      Analytics: () => fail(Analytics),
      fltool.AndroidBuilder: () => fail(fltool.AndroidBuilder),
      fltool.AndroidLicenseValidator: () =>
          fail(fltool.AndroidLicenseValidator),
      fltool.AndroidSdk: () => fail(fltool.AndroidSdk),
      fltool.AndroidStudio: () => fail(fltool.AndroidStudio),
      fltool.AndroidValidator: () => fail(fltool.AndroidValidator),
      fltool.AndroidWorkflow: () => fail(fltool.AndroidWorkflow),
      fltool.ApplicationPackageFactory: () =>
          fail(fltool.ApplicationPackageFactory),
      fltool.Artifacts: () => fail(fltool.Artifacts),
      fltool.AssetBundleFactory: () => fail(fltool.AssetBundleFactory),
      fltool.BotDetector: () => fail(fltool.BotDetector),
      fltool.BuildSystem: () => fail(fltool.BuildSystem),
      fltool.BuildTargets: () => fail(fltool.BuildTargets),
      fltool.Cache: () => fail(fltool.Cache),
      fltool.CocoaPods: () => fail(fltool.CocoaPods),
      fltool.CocoaPodsValidator: () => fail(fltool.CocoaPodsValidator),
      fltool.Config: () => fail(fltool.Config),
      fltool.CustomDevicesConfig: () => fail(fltool.CustomDevicesConfig),
      fltool.CrashReporter: () => fail(fltool.CrashReporter),
      fltool.DevFSConfig: () => fail(fltool.DevFSConfig),
      fltool.DeviceManager: () => fail(fltool.DeviceManager),
      fltool.DevtoolsLauncher: () => fail(fltool.DevtoolsLauncher),
      fltool.Doctor: () => fail(fltool.Doctor),
      fltool.DoctorValidatorsProvider: () =>
          fail(fltool.DoctorValidatorsProvider),
      fltool.EmulatorManager: () => fail(fltool.EmulatorManager),
      fltool.FeatureFlags: () => fail(fltool.FeatureFlags),
      fltool.FlutterVersion: () => fail(fltool.FlutterVersion),
      fltool.FlutterCommand: () => fail(fltool.FlutterCommand),
      fltool.FlutterProjectFactory: () => fail(fltool.FlutterProjectFactory),
      fltool.FileSystem: () => fail(fltool.FileSystem),
      fltool.FileSystemUtils: () => fail(fltool.FileSystemUtils),
      fltool.GradleUtils: () => fail(fltool.GradleUtils),
      fltool.HotRunnerConfig: () => fail(fltool.HotRunnerConfig),
      fltool.IOSSimulatorUtils: () => fail(fltool.IOSSimulatorUtils),
      fltool.IOSWorkflow: () => fail(fltool.IOSWorkflow),
      fltool.Java: () => fail(fltool.Java),
      fltool.LocalEngineLocator: () => fail(fltool.LocalEngineLocator),
      fltool.Logger: () => fail(fltool.Logger),
      fltool.MacOSWorkflow: () => fail(fltool.MacOSWorkflow),
      fltool.MDnsVmServiceDiscovery: () => fail(fltool.MDnsVmServiceDiscovery),
      fltool.OperatingSystemUtils: () => fail(fltool.OperatingSystemUtils),
      fltool.OutputPreferences: () => fail(fltool.OutputPreferences),
      fltool.PersistentToolState: () => fail(fltool.PersistentToolState),
      fltool.ProcessInfo: () => fail(fltool.ProcessInfo),
      fltool.PlistParser: () => fail(fltool.PlistParser),
      ProcessManager: () => fail(ProcessManager),
      fltool.TemplateRenderer: () => fail(fltool.TemplateRenderer),
      fltool.Platform: () => fail(fltool.Platform),
      fltool.ProcessUtils: () => fail(fltool.ProcessUtils),
      fltool.Pub: () => fail(fltool.Pub),
      fltool.Stdio: () => fail(fltool.Stdio),
      fltool.SystemClock: () => fail(fltool.SystemClock),
      fltool.Signals: () => fail(fltool.Signals),
      fltool.Usage: () => fail(fltool.Usage),
      fltool.UserMessages: () => fail(fltool.UserMessages),
      fltool.VisualStudioValidator: () => fail(fltool.VisualStudioValidator),
      fltool.WebWorkflow: () => fail(fltool.WebWorkflow),
      fltool.WindowsWorkflow: () => fail(fltool.WindowsWorkflow),
      fltool.Xcode: () => fail(fltool.Xcode),
      fltool.XCDevice: () => fail(fltool.XCDevice),
      fltool.XcodeProjectInterpreter: () =>
          fail(fltool.XcodeProjectInterpreter),

      // flutterpi_tool globals
      FlutterPiToolConfig: () => fail(FlutterPiToolConfig),
      SshUtils: () => fail(SshUtils),
      AppBuilder: () => fail(AppBuilder),
    },

    // WebSocketConnector
    // VMServiceConnector
    // HttpClientFactory
    // MDnsVmServiceDiscovery
    // WebRunnerFactory
    // TemplatePathProvider
    // PreRunValidator
    // TestCompilerNativeAssetsBuilder

    overrides: overrides,
  );
}

Future<V> runInTestContext<V>(
  FutureOr<V> Function() body, {
  MyGithub? github,
  Map<Type, fltool.Generator> overrides = const {},
}) async {
  return await runInThrowingContext(
    () async {
      return await body();
    },
    overrides: {
      Analytics: () => const NoOpAnalytics(),
      fltool.Cache: () {
        final fs = globals.fs;
        fltool.Cache.flutterRoot = '/';
        return FlutterpiCache.test(
          rootOverride: fs.directory('/cache')..createSync(),
          logger: globals.logger,
          fileSystem: fs,
          platform: globals.platform,
          osUtils: globals.moreOs,
          processManager: globals.processManager,
          hooks: globals.shutdownHooks,
          github: github ?? FakeGithub(),
        );
      },
      fltool.Logger: () => fltool.BufferLogger.test(),
      fltool.Platform: () => fltool.FakePlatform(),
      FileSystem: () => MemoryFileSystem.test(),
      fltool.FlutterProjectFactory: () => fltool.FlutterProjectFactory(
            logger: globals.logger,
            fileSystem: globals.fs,
          ),
      fltool.ApplicationPackageFactory: () =>
          fltool.FlutterApplicationPackageFactory(
            androidSdk: globals.androidSdk,
            processManager: globals.processManager,
            logger: globals.logger,
            userMessages: globals.userMessages,
            fileSystem: globals.fs,
          ),
      fltool.AndroidSdk: fltool.AndroidSdk.locateAndroidSdk,
      ProcessManager: () => FakeProcessManager.empty(),
      fltool.UserMessages: () => fltool.UserMessages(),
      fltool.Config: () => fltool.Config.test(),
      fltool.FileSystemUtils: () => fltool.FileSystemUtils(
            fileSystem: globals.fs,
            platform: globals.platform,
          ),
      fltool.OperatingSystemUtils: () => MockMoreOperatingSystemUtils(),
      fltool.ProcessUtils: () => fltool.ProcessUtils(
            processManager: globals.processManager,
            logger: globals.logger,
          ),
      fltool.Doctor: () => FakeDoctor(globals.logger),
      ...overrides,
    },
  );
}
