import 'dart:ffi';
import 'dart:io';

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

Iterable<(A, B)> cartesianProduct2<A, B>(Iterable<A> a, Iterable<B> b) sync* {
  for (final fst in a) {
    for (final snd in b) {
      yield (fst, snd);
    }
  }
}

Iterable<(A, B, C)> cartesianProduct3<A, B, C>(
  Iterable<A> a,
  Iterable<B> b,
  Iterable<C> c,
) sync* {
  for (final fst in a) {
    for (final snd in b) {
      for (final thrd in c) {
        yield (fst, snd, thrd);
      }
    }
  }
}

enum Arch {
  arm,
  arm64,
  ia32,
  x64,
  riscv32,
  riscv64;

  factory Arch.fromAbi(Abi abi) {
    return switch (abi) {
      Abi.androidArm => Arch.arm,
      Abi.androidArm64 => Arch.arm64,
      Abi.androidIA32 => Arch.ia32,
      Abi.androidX64 => Arch.x64,
      Abi.androidRiscv64 => Arch.riscv64,
      Abi.fuchsiaArm64 => Arch.arm64,
      Abi.fuchsiaX64 => Arch.x64,
      Abi.fuchsiaRiscv64 => Arch.riscv64,
      Abi.iosArm => Arch.arm,
      Abi.iosArm64 => Arch.arm64,
      Abi.iosX64 => Arch.x64,
      Abi.linuxArm => Arch.arm,
      Abi.linuxArm64 => Arch.arm64,
      Abi.linuxIA32 => Arch.ia32,
      Abi.linuxX64 => Arch.x64,
      Abi.linuxRiscv32 => Arch.riscv32,
      Abi.linuxRiscv64 => Arch.riscv64,
      Abi.macosArm64 => Arch.arm64,
      Abi.macosX64 => Arch.x64,
      Abi.windowsArm64 => Arch.arm64,
      Abi.windowsIA32 => Arch.ia32,
      Abi.windowsX64 => Arch.x64,
      _ => throw ArgumentError.value(abi, 'abi', 'unsupported abi')
    };
  }

  factory Arch.current() {
    return Arch.fromAbi(Abi.current());
  }

  @override
  String toString() => name;
}

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

    expect(
      await Process.run('file', ['--version']),
      exitedSuccessfully(),
      reason: '"file" utility must be available in PATH.',
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
  group(
    'hooks_test native assets e2e',
    () {
      const exampleDir = 'e2e/hooks_test_package/example';

      setUp(() async {
        // Ensure dependencies are installed
        final pubGetResult = await Process.run(
          'flutter',
          [
            'pub',
            'get',
            '--enforce-lockfile',
          ],
          workingDirectory: exampleDir,
        );
        expect(pubGetResult, exitedSuccessfully());
      });

      tearDown(() async {
        final clean = await Process.run(
          'flutter',
          ['clean'],
          workingDirectory: exampleDir,
        );
        expect(clean, exitedSuccessfully());
      });

      for (final (flavor, arch, layout) in cartesianProduct3(
        ['debug', 'profile', 'release'],
        [Arch.arm, Arch.arm64, Arch.x64, Arch.riscv64],
        ['flutter-pi', 'meta-flutter'],
      )) {
        test(
          'builds successfully in $flavor, for $arch, $layout layout',
          () async {
            if (arch == Arch.arm) {
              return markTestSkipped(
                'armv7 does not currently support native assets',
              );
            } else if (arch != Arch.current()) {
              return markTestSkipped(
                'cross-compiling native assets is not currently supported',
              );
            }

            final result = await Process.run(
              'flutterpi_tool',
              [
                'build',
                '--$flavor',
                '--arch=$arch',
                '--fs-layout=$layout',
              ],
              workingDirectory: exampleDir,
            );

            final layoutPart = switch (layout) {
              'flutter-pi' => '',
              'meta-flutter' => 'meta-flutter-',
              _ => fail('unexpected layout: $layout')
            };
            final archPart = switch (arch) {
              Arch.arm => 'armv7-generic',
              Arch.arm64 => 'aarch64-generic',
              Arch.ia32 => 'i386-generic',
              Arch.x64 => 'x86_64-generic',
              Arch.riscv32 => 'riscv32-generic',
              Arch.riscv64 => 'riscv64-generic',
            };
            final outputDir = pathlib.join(
              exampleDir,
              'build',
              'flutter-pi',
              '$layoutPart$archPart',
            );
            final testAsset = switch (layout) {
              'flutter-pi' =>
                pathlib.join(outputDir, 'libhooks_test_package.so'),
              'meta-flutter' =>
                pathlib.join(outputDir, 'lib', 'libhooks_test_package.so'),
              _ => fail('unexpected layout: $layout'),
            };

            expect(result, buildExitedSuccessfully());
            expect(
              File(testAsset).existsSync(),
              isTrue,
              reason:
                  'libhooks_test_package.so code asset should be present in bundle',
            );

            final fileResult = await Process.run('file', [testAsset]);
            expect(fileResult, exitedSuccessfully());

            final fileArchMatcher = switch (arch) {
              Arch.arm64 => contains('ARM aarch64'),
              _ => isNot(anything),
            };
            expect(fileResult.stdout, fileArchMatcher);
          },
          timeout: const Timeout(Duration(minutes: 5)),
        );
      }
    },
    testOn: 'linux',
  );

  test('empty test to make all-skipped runs succeed', () {});
}
