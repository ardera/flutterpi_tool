// ignore_for_file: implementation_imports

import 'package:flutterpi_tool/src/fltool/common.dart' show BuildMode;

enum Bitness { b32, b64 }

enum FlutterpiHostPlatform {
  darwinX64.b64('darwin-x64', 'macOS-X64', darwin: true),
  darwinARM64.b64('darwin-arm64', 'macOS-ARM64', darwin: true),
  linuxX64.b64('linux-x64', 'Linux-X64', linux: true),
  linuxARM.b32('linux-arm', 'Linux-ARM', linux: true),
  linuxARM64.b64('linux-arm64', 'Linux-ARM64', linux: true),
  linuxRV64.b64('linux-riscv64', 'Linux-RISCV64', linux: true),
  windowsX64.b64('windows-x64', 'Windows-X64', windows: true),
  windowsARM64.b64('windows-arm64', 'Windows-ARM64', windows: true);

  const FlutterpiHostPlatform.b32(
    this.name,
    this.githubName, {
    bool darwin = false,
    bool linux = false,
    bool windows = false,
  })  : bitness = Bitness.b32,
        isDarwin = darwin,
        isLinux = linux,
        isWindows = windows,
        isPosix = linux || darwin,
        assert(
          (darwin ? 1 : 0) + (linux ? 1 : 0) + (windows ? 1 : 0) == 1,
          'Exactly one of darwin, linux, or windows must be specified.',
        );

  const FlutterpiHostPlatform.b64(
    this.name,
    this.githubName, {
    bool darwin = false,
    bool linux = false,
    bool windows = false,
  })  : bitness = Bitness.b64,
        isDarwin = darwin,
        isLinux = linux,
        isWindows = windows,
        isPosix = linux || darwin,
        assert(
          (darwin ? 1 : 0) + (linux ? 1 : 0) + (windows ? 1 : 0) == 1,
          'Exactly one of darwin, linux, or windows must be specified.',
        );

  final String name;
  final String githubName;
  final Bitness bitness;
  final bool isDarwin;
  final bool isLinux;
  final bool isPosix;
  final bool isWindows;

  @override
  String toString() => name;
}

enum FlutterpiTargetPlatform {
  genericArmV7.generic32('armv7-generic', 'arm-linux-gnueabihf'),
  genericAArch64.generic64('aarch64-generic', 'aarch64-linux-gnu'),
  genericX64.generic64('x64-generic', 'x86_64-linux-gnu'),
  genericRiscv64.generic64('riscv64-generic', 'riscv64-linux-gnu'),
  pi3.tuned32('pi3', 'armv7-generic', 'arm-linux-gnueabihf'),
  pi3_64.tuned64('pi3-64', 'aarch64-generic', 'aarch64-linux-gnu'),
  pi4.tuned32('pi4', 'armv7-generic', 'arm-linux-gnueabihf'),
  pi4_64.tuned64('pi4-64', 'aarch64-generic', 'aarch64-linux-gnu');

  const FlutterpiTargetPlatform.generic64(this.shortName, this.triple)
      : isGeneric = true,
        _genericVariantStr = null,
        bitness = Bitness.b64;

  const FlutterpiTargetPlatform.generic32(this.shortName, this.triple)
      : isGeneric = true,
        _genericVariantStr = null,
        bitness = Bitness.b32;

  const FlutterpiTargetPlatform.tuned32(
    this.shortName,
    this._genericVariantStr,
    this.triple,
  )   : isGeneric = false,
        bitness = Bitness.b32;

  const FlutterpiTargetPlatform.tuned64(
    this.shortName,
    this._genericVariantStr,
    this.triple,
  )   : isGeneric = false,
        bitness = Bitness.b64;

  final Bitness bitness;
  final String shortName;
  final bool isGeneric;
  final String? _genericVariantStr;
  final String triple;

  FlutterpiTargetPlatform get genericVariant {
    if (_genericVariantStr != null) {
      return values
          .singleWhere((target) => target.shortName == _genericVariantStr);
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

  const EngineFlavor._internal(
    this.name,
    this.buildMode, {
    this.unoptimized = false,
  });

  factory EngineFlavor(BuildMode mode, bool unoptimized) {
    return switch ((mode, unoptimized)) {
      (BuildMode.debug, true) => debugUnopt,
      (BuildMode.debug, false) => debug,
      (BuildMode.profile, false) => profile,
      (BuildMode.release, false) => release,
      (_, true) => throw ArgumentError.value(
          unoptimized,
          'unoptimized',
          'Unoptimized builds are only supported for debug engine.',
        ),
      _ => throw ArgumentError.value(mode, 'mode', 'Illegal build mode'),
    };
  }

  final String name;

  final BuildMode buildMode;
  final bool unoptimized;

  @override
  String toString() => name;
}
