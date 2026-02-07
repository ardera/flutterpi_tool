import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('hooks_test native assets e2e', () {
    const exampleDir = 'e2e/hooks_test_package/example';

    setUpAll(() async {
      // Ensure dependencies are installed
      final pubGetResult = await Process.run(
        'flutter',
        ['pub', 'get', '--enforce-lockfile'],
        workingDirectory: exampleDir,
      );
      expect(
        pubGetResult.exitCode,
        0,
        reason: 'flutter pub get should succeed',
      );
    });

    test('builds successfully in debug mode', () async {
      final result = await Process.run(
        'flutterpi_tool',
        ['build', '--debug'],
        workingDirectory: exampleDir,
      );

      expect(result.exitCode, 0,
          reason: 'Build should succeed with exit code 0');
      expect(
          result.stderr.toString(), isNot(contains('Failed to build bundle.')));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('builds successfully in profile mode', () async {
      final result = await Process.run(
        'flutterpi_tool',
        ['build', '--profile'],
        workingDirectory: exampleDir,
      );

      expect(result.exitCode, 0,
          reason: 'Build should succeed with exit code 0');
      expect(
          result.stderr.toString(), isNot(contains('Failed to build bundle.')));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('builds successfully in release mode', () async {
      final result = await Process.run(
        'flutterpi_tool',
        ['build', '--release'],
        workingDirectory: exampleDir,
      );

      expect(result.exitCode, 0,
          reason: 'Build should succeed with exit code 0');
      expect(
          result.stderr.toString(), isNot(contains('Failed to build bundle.')));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
