import 'dart:async';

import 'package:test/test.dart';

import 'package:flutterpi_tool/src/fltool/common.dart' as fl;

class MockBuildSystem implements fl.BuildSystem {
  Future<fl.BuildResult> Function(
    fl.Target target,
    fl.Environment environment, {
    fl.BuildSystemConfig buildSystemConfig,
  })? buildFn;

  @override
  Future<fl.BuildResult> build(
    fl.Target target,
    fl.Environment environment, {
    fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
  }) {
    if (buildFn == null) {
      fail('Expected buildFn to not be called.');
    }

    return buildFn!(target, environment, buildSystemConfig: buildSystemConfig);
  }

  Future<fl.BuildResult> Function(
    fl.Target target,
    fl.Environment environment,
    fl.BuildResult? previousBuild,
  )? buildIncrementalFn;

  @override
  Future<fl.BuildResult> buildIncremental(
    fl.Target target,
    fl.Environment environment,
    fl.BuildResult? previousBuild,
  ) {
    if (buildIncrementalFn == null) {
      fail('Expected buildIncrementalFn to not be called.');
    }

    return buildIncrementalFn!(target, environment, previousBuild);
  }
}
