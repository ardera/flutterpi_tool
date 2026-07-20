import 'dart:convert';

/// Rewrites stock Linux bundled-code locations for a flutter-pi bundle.
///
/// Flutter's Linux runner CMake installs `DynamicLoadingBundled` assets into a
/// directory covered by the runner's `$ORIGIN/lib` RUNPATH. The generated
/// manifest therefore encodes those basenames as `absolute`. flutter-pi has no
/// runner CMake install phase or equivalent RUNPATH; [copiedBasenames] are
/// installed beside `app.so` instead and must be resolved relative to it.
///
/// Only `absolute` entries whose basename was actually copied are changed.
/// System/relative/process/executable assets and unrelated absolute paths are
/// preserved exactly, apart from JSON whitespace.
String rewriteNativeAssetsManifestForFlutterPi(
  String manifestJson,
  Set<String> copiedBasenames,
) {
  final document = jsonDecode(manifestJson);
  if (document is! Map<String, dynamic>) {
    throw const FormatException(
      'Native Assets manifest root must be an object.',
    );
  }
  final nativeAssets = document['native-assets'];
  if (nativeAssets is! Map<String, dynamic>) {
    return jsonEncode(document);
  }

  for (final targetAssets in nativeAssets.values) {
    if (targetAssets is! Map<String, dynamic>) continue;
    for (final location in targetAssets.values) {
      if (location is! List<dynamic> || location.length != 2) continue;
      final kind = location[0];
      final path = location[1];
      if (kind == 'absolute' &&
          path is String &&
          copiedBasenames.contains(path)) {
        location[0] = 'relative';
      }
    }
  }

  return jsonEncode(document);
}
