import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as pathlib;
import 'package:test/test.dart';

/// Custom matcher that checks if a ProcessResult succeeded
/// and provides helpful error messages with stdout/stderr on failure.
class _ProcessExitedSuccessfully extends Matcher {
  _ProcessExitedSuccessfully({Object? exitCode, Object? stdout, Object? stderr})
      : exitCode = wrapMatcher(exitCode ?? equals(0)),
        stdout = wrapMatcher(stdout ?? anything),
        stderr = wrapMatcher(stderr ?? anything);

  final Matcher exitCode;
  final Matcher stdout;
  final Matcher stderr;

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! ProcessResult) return false;

    final exitCode = this.exitCode;
    if (!exitCode.matches(item.exitCode, matchState)) {
      matchState['exitCodeMatcher'] = exitCode;
      matchState['field'] = 'exitCode';
      return false;
    }

    if (!stdout.matches(item.stdout, matchState)) {
      matchState['stdoutMatcher'] = stdout;
      matchState['field'] = 'stdout';
      return false;
    }

    if (!stderr.matches(item.stderr, matchState)) {
      matchState['stderrMatcher'] = stderr;
      matchState['field'] = 'stderr';
      return false;
    }

    return true;
  }

  @override
  Description describe(Description description) {
    description.add('process to succeed');

    description.add(' with exit code ');
    exitCode.describe(description);

    description.add(' and stdout ');
    stdout.describe(description);

    description.add(' and stderr ');
    stderr.describe(description);

    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! ProcessResult) {
      return mismatchDescription.add('is not a ProcessResult');
    }

    final field = matchState['field'] as String?;

    if (field == 'exitCode') {
      final matcher = matchState['exitCodeMatcher'] as Matcher;
      mismatchDescription.add('exit code ');
      matcher.describeMismatch(
        item.exitCode,
        mismatchDescription,
        matchState,
        verbose,
      );
    } else if (field == 'stdout') {
      final matcher = matchState['stdoutMatcher'] as Matcher;
      mismatchDescription.add('stdout ');
      matcher.describeMismatch(
        item.stdout,
        mismatchDescription,
        matchState,
        verbose,
      );
    } else if (field == 'stderr') {
      final matcher = matchState['stderrMatcher'] as Matcher;
      mismatchDescription.add('stderr ');
      matcher.describeMismatch(
        item.stderr,
        mismatchDescription,
        matchState,
        verbose,
      );
    }

    // Always include the full process output for context
    return mismatchDescription
        .add('\n\nProcess output:')
        .add('\nexit code: ${item.exitCode}')
        .add('\nstdout: ${item.stdout}')
        .add('\nstderr: ${item.stderr}');
  }
}

Matcher exitedSuccessfully({
  Matcher? exitCode,
  Matcher? stdout,
  Matcher? stderr,
}) =>
    _ProcessExitedSuccessfully(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );

Matcher buildExitedSuccessfully() => _ProcessExitedSuccessfully(
      stdout: isNot(contains('Failed to build bundle.')),
      stderr: isNot(contains('Failed to build bundle.')),
    );

void main() {
  setUpAll(() async {
    expect(
      await Process.run('flutter', ['--version']),
      exitedSuccessfully(),
      reason: 'flutter must be available in PATH.',
    );

    expect(
      await Process.run('flutterpi_tool', ['--version']),
      exitedSuccessfully(),
      reason:
          'flutterpi_tool must be globally activated and available in PATH.',
    );

    final result = await Process.run('dart', ['pub', 'global', 'list']);
    expect(
      result,
      exitedSuccessfully(),
      reason: 'dart must be available in PATH.',
    );

    final regex = RegExp(r'flutterpi_tool [^ ]+ at path "([^"]+)"');
    expect(result.stdout, matches(regex));

    final match = regex.firstMatch(result.stdout);
    expect(
      Directory(match!.group(1)!).resolveSymbolicLinksSync(),
      pathlib.canonicalize(Directory.current.path),
      reason:
          'flutterpi_tool should be globally activated from the same path that is currently being tested.',
    );
  });

  // Only tested on linux right now, see testOn below.
  // On windows and macOS it's hard to get a working linux
  // cross compiler. Best thing we can do maybe is just
  // verify we provide an understandable error message.
  group('hooks_test native assets e2e', () {
    const exampleDir = 'e2e/hooks_test_package/example';

    final testAssetFlutterPi = File(pathlib.join(
      exampleDir,
      'build',
      'flutter-pi',
      'armv7-generic',
      'libhooks_test_package.so',
    ));

    final testAssetMetaFlutter = File(pathlib.join(
      exampleDir,
      'build',
      'flutter-pi',
      'armv7-generic-meta-flutter',
      'lib',
      'libhooks_test_package.so',
    ));

    setUp(() async {
      // Ensure dependencies are installed
      final pubGetResult = await Process.run(
          'flutter',
          [
            'pub',
            'get',
            '--enforce-lockfile',
          ],
          workingDirectory: exampleDir);
      expect(pubGetResult, exitedSuccessfully());
    });

    tearDown(() async {
      final clean =
          await Process.run('flutter', ['clean'], workingDirectory: exampleDir);
      expect(clean, exitedSuccessfully());
    });

    test(
      'builds successfully in debug mode',
      () async {
        final result = await Process.run(
            'flutterpi_tool',
            [
              'build',
              '--debug',
            ],
            workingDirectory: exampleDir);

        expect(result, buildExitedSuccessfully());
        expect(
          testAssetFlutterPi.existsSync(),
          isTrue,
          reason:
              'libhooks_test_package.so code asset should be present in bundle',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'builds successfully in profile mode',
      () async {
        final result = await Process.run(
            'flutterpi_tool',
            [
              'build',
              '--profile',
            ],
            workingDirectory: exampleDir);

        expect(result, buildExitedSuccessfully());
        expect(
          testAssetFlutterPi.existsSync(),
          isTrue,
          reason:
              'libhooks_test_package.so code asset should be present in bundle',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'builds successfully in release mode',
      () async {
        final result = await Process.run(
            'flutterpi_tool',
            [
              'build',
              '--release',
            ],
            workingDirectory: exampleDir);

        expect(result, buildExitedSuccessfully());
        expect(
          testAssetFlutterPi.existsSync(),
          isTrue,
          reason:
              'libhooks_test_package.so code asset should be present in bundle',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }, testOn: 'linux');
}
