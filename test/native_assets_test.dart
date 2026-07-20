import 'dart:convert';

import 'package:test/test.dart';
import 'package:flutterpi_tool/src/build_system/native_assets.dart';

void main() {
  test('rewrites only installed bundled Linux code assets', () {
    final input = jsonEncode({
      'format-version': [1, 0, 0],
      'native-assets': {
        'linux_arm64': {
          'package:webcrypto/lookup.dart': ['absolute', 'libwebcrypto.so'],
          'package:fllama/fllama.dart': ['absolute', 'libfllama.so'],
          'package:system/system.dart': ['absolute', '/usr/lib/libsystem.so'],
          'package:process/process.dart': ['process'],
          'package:relative/relative.dart': ['relative', 'already-relative.so'],
        },
      },
    });

    final rewritten = jsonDecode(
      rewriteNativeAssetsManifestForFlutterPi(input, {
        'libwebcrypto.so',
        'libfllama.so',
      }),
    ) as Map<String, dynamic>;
    final assets = (rewritten['native-assets']
        as Map<String, dynamic>)['linux_arm64'] as Map<String, dynamic>;

    expect(assets['package:webcrypto/lookup.dart'], [
      'relative',
      'libwebcrypto.so',
    ]);
    expect(assets['package:fllama/fllama.dart'], [
      'relative',
      'libfllama.so',
    ]);
    expect(assets['package:system/system.dart'], [
      'absolute',
      '/usr/lib/libsystem.so',
    ]);
    expect(assets['package:process/process.dart'], ['process']);
    expect(assets['package:relative/relative.dart'], [
      'relative',
      'already-relative.so',
    ]);
  });

  test('preserves bundled entries that were not copied', () {
    final input = jsonEncode({
      'native-assets': {
        'linux_x64': {
          'package:missing/missing.dart': ['absolute', 'libmissing.so'],
        },
      },
    });

    final rewritten = jsonDecode(
      rewriteNativeAssetsManifestForFlutterPi(input, {'libwebcrypto.so'}),
    ) as Map<String, dynamic>;
    final assets = (rewritten['native-assets']
        as Map<String, dynamic>)['linux_x64'] as Map<String, dynamic>;

    expect(assets['package:missing/missing.dart'], [
      'absolute',
      'libmissing.so',
    ]);
  });

  test('rejects a non-object manifest root', () {
    expect(
      () => rewriteNativeAssetsManifestForFlutterPi('[]', const {}),
      throwsFormatException,
    );
  });
}
