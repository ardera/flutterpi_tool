import 'package:file/file.dart';
import 'package:flutterpi_tool/src/build_system/extended_environment.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';

sealed class FlutterpiArtifact {
  const FlutterpiArtifact();
}

final class FlutterpiBinary extends FlutterpiArtifact {
  const FlutterpiBinary({required this.target, required this.mode});

  final FlutterpiTargetPlatform target;
  final BuildMode mode;
}

final class Engine extends FlutterpiArtifact {
  const Engine({required this.target, required this.flavor});

  final FlutterpiTargetPlatform target;
  final EngineFlavor flavor;
}

final class EngineDebugSymbols extends FlutterpiArtifact {
  const EngineDebugSymbols({
    required this.target,
    required this.flavor,
  });

  final FlutterpiTargetPlatform target;
  final EngineFlavor flavor;
}

final class GenSnapshot extends FlutterpiArtifact {
  const GenSnapshot({
    required this.host,
    required this.target,
    required this.mode,
  }) : assert(mode == BuildMode.release || mode == BuildMode.profile);

  final FlutterpiHostPlatform host;
  final FlutterpiTargetPlatform target;
  final BuildMode mode;
}

abstract class FlutterpiArtifacts implements Artifacts {
  File getFlutterpiArtifact(FlutterpiArtifact artifact);
}

class CachedFlutterpiArtifacts implements FlutterpiArtifacts {
  CachedFlutterpiArtifacts({
    required this.inner,
    required this.cache,
  });

  final Artifacts inner;
  final FlutterpiCache cache;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return inner.getArtifactPath(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  @override
  File getFlutterpiArtifact(FlutterpiArtifact artifact) {
    return switch (artifact) {
      FlutterpiBinary(:final target, :final mode) => cache
          .getArtifactDirectory('flutter-pi')
          .childDirectory(target.triple)
          .childDirectory(
            switch (mode) {
              BuildMode.debug => 'debug',
              BuildMode.profile ||
              BuildMode.release ||
              BuildMode.jitRelease =>
                'release',
            },
          )
          .childFile('flutter-pi'),
      Engine(:final target, :final flavor) => cache
          .getArtifactDirectory('engine')
          .childDirectory('flutterpi-engine-$target-$flavor')
          .childFile('libflutter_engine.so'),
      EngineDebugSymbols(:final target, :final flavor) => cache
          .getArtifactDirectory('engine')
          .childDirectory('flutterpi-engine-dbgsyms-$target-$flavor')
          .childFile('libflutter_engine.dbgsyms'),
      GenSnapshot(:final host, :final target, :final mode) => cache
          .getArtifactDirectory('engine')
          .childDirectory('flutterpi-gen-snapshot-$host-$target-$mode')
          .childFile('gen_snapshot')
    };
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) {
    return inner.getEngineType(platform, mode);
  }

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    return inner.getHostArtifact(artifact);
  }

  @override
  LocalEngineInfo? get localEngineInfo => inner.localEngineInfo;

  @override
  bool get usesLocalArtifacts => inner.usesLocalArtifacts;
}

class FlutterpiArtifactsWrapper implements FlutterpiArtifacts {
  FlutterpiArtifactsWrapper({
    required this.inner,
  });

  final FlutterpiArtifacts inner;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return inner.getArtifactPath(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  @override
  File getFlutterpiArtifact(FlutterpiArtifact artifact) {
    return inner.getFlutterpiArtifact(artifact);
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) {
    return inner.getEngineType(platform, mode);
  }

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    return inner.getHostArtifact(artifact);
  }

  @override
  LocalEngineInfo? get localEngineInfo => inner.localEngineInfo;

  @override
  bool get usesLocalArtifacts => inner.usesLocalArtifacts;
}

class FlutterToFlutterpiArtifactsForwarder extends FlutterpiArtifactsWrapper {
  FlutterToFlutterpiArtifactsForwarder({
    required super.inner,
    required this.host,
    required this.target,
  });

  final FlutterpiHostPlatform host;
  final FlutterpiTargetPlatform target;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return switch (artifact) {
      Artifact.genSnapshot => inner
          .getFlutterpiArtifact(
            GenSnapshot(host: host, target: target.genericVariant, mode: mode!),
          )
          .path,
      _ => inner.getArtifactPath(
          artifact,
          platform: platform,
          mode: mode,
          environmentType: environmentType,
        ),
    };
  }
}

class LocalFlutterpiBinaryOverride extends FlutterpiArtifactsWrapper {
  LocalFlutterpiBinaryOverride({
    required super.inner,
    required this.flutterpiBinary,
  });

  final File flutterpiBinary;

  @override
  File getFlutterpiArtifact(FlutterpiArtifact artifact) {
    return switch (artifact) {
      FlutterpiBinary _ => flutterpiBinary,
      _ => inner.getFlutterpiArtifact(artifact),
    };
  }

  @override
  bool get usesLocalArtifacts => true;
}

extension _VisitFlutterpiArtifact on SourceVisitor {
  void visitFlutterpiArtifact(FlutterpiArtifact artifact) {
    final environment = this.environment;
    if (environment is! ExtendedEnvironment) {
      throw StateError(
        'Expected environment to be a FlutterpiEnvironment, '
        'but got ${environment.runtimeType}.',
      );
    }

    final artifactFile = environment.artifacts.getFlutterpiArtifact(artifact);
    assert(artifactFile.fileSystem == environment.fileSystem);

    sources.add(artifactFile);
  }
}

extension SourceFlutterpiArtifactSource on Source {
  static Source flutterpiArtifact(FlutterpiArtifact artifact) {
    return FlutterpiArtifactSource(artifact);
  }
}

class FlutterpiArtifactSource implements Source {
  final FlutterpiArtifact artifact;

  const FlutterpiArtifactSource(
    this.artifact,
  );

  @override
  void accept(SourceVisitor visitor) {
    visitor.visitFlutterpiArtifact(artifact);
  }

  @override
  bool get implicit => false;
}
