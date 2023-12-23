// ignore_for_file: implementation_imports

import 'package:flutter_tools/src/build_info.dart' show BuildMode;

export 'package:flutter_tools/src/build_info.dart' show BuildMode, getCurrentHostPlatform;
export 'package:flutter_tools/src/base/os.dart' show HostPlatform, getNameForHostPlatform;

enum FlutterpiTargetPlatform {
  genericArmV7.generic('armv7-generic'),
  genericAArch64.generic('aarch64-generic'),
  genericX64.generic('x64-generic'),
  pi3.tuned('pi3', 'armv7-generic'),
  pi3_64.tuned('pi3-64', 'aarch64-generic'),
  pi4.tuned('pi4', 'armv7-generic'),
  pi4_64.tuned('pi4-64', 'aarch64-generic');

  const FlutterpiTargetPlatform.generic(this.shortName)
      : isGeneric = true,
        _genericVariantStr = null;

  const FlutterpiTargetPlatform.tuned(this.shortName, this._genericVariantStr) : isGeneric = false;

  final String shortName;
  final bool isGeneric;
  final String? _genericVariantStr;
  FlutterpiTargetPlatform get genericVariant {
    if (_genericVariantStr != null) {
      return values.singleWhere((target) => target.shortName == _genericVariantStr);
    } else {
      return this;
    }
  }

  @override
  String toString() {
    return shortName;
  }
}

enum EngineFlavor {
  debugUnopt._internal('debug_unopt', BuildMode.debug, unoptimized: true),
  debug._internal('debug', BuildMode.debug),
  profile._internal('profile', BuildMode.profile),
  release._internal('release', BuildMode.release);

  const EngineFlavor._internal(this._name, this.buildMode, {this.unoptimized = false});

  factory EngineFlavor(BuildMode mode, bool unoptimized) {
    return switch ((mode, unoptimized)) {
      (BuildMode.debug, true) => debugUnopt,
      (BuildMode.debug, false) => debug,
      (BuildMode.profile, false) => profile,
      (BuildMode.release, false) => release,
      (_, true) => throw ArgumentError.value(
          unoptimized, 'unoptimized', 'Unoptimized builds are only supported for debug engine.'),
      _ => throw ArgumentError.value(mode, 'mode', 'Illegal build mode'),
    };
  }

  final String _name;

  final BuildMode buildMode;
  final bool unoptimized;

  @override
  String toString() => _name;
}
