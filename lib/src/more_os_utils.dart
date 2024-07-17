import 'package:file/file.dart';
import 'package:flutterpi_tool/src/archive.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/common.dart';

enum ArchiveType {
  tarXz,
  tarGz,
  tar,
  zip,
}

abstract class MoreOperatingSystemUtils implements OperatingSystemUtils {
  factory MoreOperatingSystemUtils({
    required FileSystem fileSystem,
    required Logger logger,
    required Platform platform,
    required ProcessManager processManager,
  }) {
    final os = OperatingSystemUtils(
      fileSystem: fileSystem,
      logger: logger,
      platform: platform,
      processManager: processManager,
    );

    var moreOs = MoreOperatingSystemUtils.wrap(os);

    final processUtils = ProcessUtils(
      processManager: processManager,
      logger: logger,
    );

    if (platform.isMacOS) {
      moreOs = MacosMoreOsUtils(
        delegate: moreOs,
        processUtils: processUtils,
      );
    } else if (platform.isLinux) {
      moreOs = LinuxMoreOsUtils(
        delegate: moreOs,
        processUtils: processUtils,
        logger: logger,
      );
    }

    return moreOs;
  }

  factory MoreOperatingSystemUtils.wrap(OperatingSystemUtils os) =>
      MoreOperatingSystemUtilsWrapper(os: os);

  FlutterpiHostPlatform get fpiHostPlatform;

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory,
      {ArchiveType? type, Archive Function(File)? decoder});
}

class MoreOperatingSystemUtilsWrapper implements MoreOperatingSystemUtils {
  MoreOperatingSystemUtilsWrapper({
    required this.os,
  });

  final OperatingSystemUtils os;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    return os.chmod(entity, mode);
  }

  @override
  HostPlatform get hostPlatform => os.hostPlatform;

  @override
  FlutterpiHostPlatform get fpiHostPlatform {
    return switch (hostPlatform) {
      HostPlatform.darwin_x64 => FlutterpiHostPlatform.darwinX64,
      HostPlatform.darwin_arm64 => FlutterpiHostPlatform.darwinARM64,
      HostPlatform.linux_x64 => FlutterpiHostPlatform.linuxX64,
      HostPlatform.linux_arm64 => FlutterpiHostPlatform.linuxARM64,
      HostPlatform.windows_x64 => FlutterpiHostPlatform.windowsX64,
      HostPlatform.windows_arm64 => FlutterpiHostPlatform.windowsARM64,
    };
  }

  @override
  void makeExecutable(File file) {
    return os.makeExecutable(file);
  }

  @override
  File makePipe(String path) => os.makePipe(path);

  @override
  String get pathVarSeparator => os.pathVarSeparator;

  @override
  void unpack(
    File gzippedTarFile,
    Directory targetDirectory, {
    Archive Function(File)? decoder,
    ArchiveType? type,
  }) {
    if (decoder == null && type == null || type == ArchiveType.tarGz) {
      return os.unpack(gzippedTarFile, targetDirectory);
    } else {
      decoder ??= switch (type) {
        ArchiveType.tarXz => (file) => TarDecoder()
            .decodeBytes(XZDecoder().decodeBytes(file.readAsBytesSync())),
        ArchiveType.tarGz => (file) => TarDecoder()
            .decodeBytes(GZipDecoder().decodeBytes(file.readAsBytesSync())),
        ArchiveType.tar => (file) =>
            TarDecoder().decodeBytes(file.readAsBytesSync()),
        ArchiveType.zip => (file) =>
            ZipDecoder().decodeBytes(file.readAsBytesSync()),
        null => throw 'unreachable',
      };

      final archive = decoder(gzippedTarFile);

      _unpackArchive(archive, targetDirectory);
    }
  }

  void _unpackArchive(Archive archive, Directory targetDirectory) {
    final fs = targetDirectory.fileSystem;

    for (final archiveFile in archive.files) {
      if (!archiveFile.isFile || archiveFile.name.endsWith('/')) {
        continue;
      }

      final destFile = fs.file(
        fs.path.canonicalize(
          fs.path.join(
            targetDirectory.path,
            archiveFile.name,
          ),
        ),
      );

      // Validate that the destFile is within the targetDirectory we want to
      // extract to.
      //
      // See https://snyk.io/research/zip-slip-vulnerability for more context.
      final destinationFileCanonicalPath = fs.path.canonicalize(destFile.path);
      final targetDirectoryCanonicalPath =
          fs.path.canonicalize(targetDirectory.path);

      if (!destinationFileCanonicalPath
          .startsWith(targetDirectoryCanonicalPath)) {
        throw StateError(
          'Tried to extract the file $destinationFileCanonicalPath outside of the '
          'target directory $targetDirectoryCanonicalPath',
        );
      }

      if (!destFile.parent.existsSync()) {
        destFile.parent.createSync(recursive: true);
      }

      destFile.writeAsBytesSync(archiveFile.content as List<int>);
    }
  }

  @override
  void unzip(File file, Directory targetDirectory) {
    return os.unzip(file, targetDirectory);
  }

  @override
  Future<int> findFreePort({bool ipv6 = false}) {
    return os.findFreePort(ipv6: ipv6);
  }

  @override
  int? getDirectorySize(Directory directory) {
    return os.getDirectorySize(directory);
  }

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) {
    return os.gzipLevel1Stream(stream);
  }

  @override
  String get name => os.name;

  @override
  File? which(String execName) {
    return os.which(execName);
  }

  @override
  List<File> whichAll(String execName) {
    return os.whichAll(execName);
  }
}

class DelegatingMoreOsUtils implements MoreOperatingSystemUtils {
  DelegatingMoreOsUtils({
    required this.delegate,
  });

  @protected
  final MoreOperatingSystemUtils delegate;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    return delegate.chmod(entity, mode);
  }

  @override
  Future<int> findFreePort({bool ipv6 = false}) {
    return delegate.findFreePort(ipv6: ipv6);
  }

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) {
    return delegate.gzipLevel1Stream(stream);
  }

  @override
  HostPlatform get hostPlatform => delegate.hostPlatform;

  @override
  FlutterpiHostPlatform get fpiHostPlatform => delegate.fpiHostPlatform;

  @override
  void makeExecutable(File file) => delegate.makeExecutable(file);

  @override
  File makePipe(String path) => delegate.makePipe(path);

  @override
  String get name => delegate.name;

  @override
  String get pathVarSeparator => delegate.pathVarSeparator;

  @override
  void unpack(
    File gzippedTarFile,
    Directory targetDirectory, {
    ArchiveType? type,
    Archive Function(File)? decoder,
  }) {
    return delegate.unpack(
      gzippedTarFile,
      targetDirectory,
      decoder: decoder,
      type: type,
    );
  }

  @override
  void unzip(File file, Directory targetDirectory) {
    return delegate.unzip(file, targetDirectory);
  }

  @override
  File? which(String execName) {
    return delegate.which(execName);
  }

  @override
  List<File> whichAll(String execName) {
    return delegate.whichAll(execName);
  }

  @override
  int? getDirectorySize(Directory directory) {
    return delegate.getDirectorySize(directory);
  }
}

class PosixMoreOsUtils extends DelegatingMoreOsUtils {
  PosixMoreOsUtils({
    required super.delegate,
    required this.processUtils,
  });

  @protected
  final ProcessUtils processUtils;

  @override
  void unpack(
    File gzippedTarFile,
    Directory targetDirectory, {
    ArchiveType? type,
    Archive Function(File)? decoder,
  }) {
    if (decoder != null) {
      return delegate.unpack(gzippedTarFile, targetDirectory,
          decoder: decoder, type: type);
    }

    switch (type) {
      case ArchiveType.tarGz:
      case ArchiveType.tarXz:
      case ArchiveType.tar:
        final formatArg = switch (type) {
          ArchiveType.tarGz => 'z',
          ArchiveType.tarXz => 'J',
          ArchiveType.tar => '',
          _ => throw 'unreachable',
        };

        processUtils.runSync(
          <String>[
            'tar',
            '-x${formatArg}f',
            gzippedTarFile.path,
            '-C',
            targetDirectory.path
          ],
          throwOnError: true,
        );
        break;

      case ArchiveType.zip:
        unzip(gzippedTarFile, targetDirectory);

      case null:
        super.unpack(gzippedTarFile, targetDirectory);
    }
  }
}

class LinuxMoreOsUtils extends PosixMoreOsUtils {
  LinuxMoreOsUtils({
    required super.delegate,
    required super.processUtils,
    required this.logger,
  });

  @protected
  final Logger logger;

  FlutterpiHostPlatform _findHostPlatform() {
    final result = processUtils.runSync(<String>['uname', '-m']);
    // On x64 stdout is "uname -m: x86_64"
    // On arm64 stdout is "uname -m: aarch64, arm64_v8a"
    if (result.exitCode != 0) {
      logger.printError(
        'Encountered an error trying to run "uname -m":\n'
        '  exit code: ${result.exitCode}\n'
        '  stdout: ${result.stdout.trimRight()}\n'
        '  stderr: ${result.stderr.trimRight()}\n'
        'Assuming host platform is ${FlutterpiHostPlatform.linuxX64}.',
      );
      return FlutterpiHostPlatform.linuxX64;
    }

    final machine = result.stdout.trim();

    if (machine.endsWith('x86_64')) {
      return FlutterpiHostPlatform.linuxX64;
    } else if (machine == 'aarch64' || machine == 'arm64') {
      return FlutterpiHostPlatform.linuxARM64;
    } else if (machine == 'armv7l' || machine == 'arm') {
      return FlutterpiHostPlatform.linuxARM;
    } else {
      logger.printError(
        'Unrecognized host platform: uname -m: $machine\n'
        'Assuming host platform is ${FlutterpiHostPlatform.linuxX64}.',
      );
      return FlutterpiHostPlatform.linuxX64;
    }
  }

  @override
  late final FlutterpiHostPlatform fpiHostPlatform = _findHostPlatform();
}

class MacosMoreOsUtils extends PosixMoreOsUtils {
  MacosMoreOsUtils({
    required super.delegate,
    required super.processUtils,
  });
}
