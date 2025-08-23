import 'package:file/src/interface/file.dart';
import 'package:file/src/interface/file_system_entity.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:test/test.dart';

class MockFlutterpiArtifacts implements FlutterpiArtifacts {
  String Function(
    Artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  })? artifactPathFn;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    if (artifactPathFn == null) {
      fail("Expected getArtifactPath to not be called.");
    }
    return artifactPathFn!(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  String Function(TargetPlatform platform, [BuildMode? mode])? getEngineTypeFn;

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) {
    if (getEngineTypeFn == null) {
      fail("Expected getEngineType to not be called.");
    }
    return getEngineTypeFn!(platform, mode);
  }

  File Function(FlutterpiArtifact artifact)? getFlutterpiArtifactFn;

  @override
  File getFlutterpiArtifact(FlutterpiArtifact artifact) {
    if (getFlutterpiArtifactFn == null) {
      fail("Expected getFlutterpiArtifact to not be called.");
    }
    return getFlutterpiArtifactFn!(artifact);
  }

  FileSystemEntity Function(HostArtifact artifact)? getHostArtifactFn;

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    if (getHostArtifactFn == null) {
      fail("Expected getHostArtifact to not be called.");
    }
    return getHostArtifactFn!(artifact);
  }

  @override
  LocalEngineInfo? localEngineInfo;

  @override
  bool usesLocalArtifacts = false;
}
