// ignore_for_file: implementation_imports

import 'package:file/file.dart';
import 'package:process/process.dart';

import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/common.dart';

abstract class FPiOperatingSystemUtils implements OperatingSystemUtils {
  factory FPiOperatingSystemUtils({
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

    var fpiOs = FPiOperatingSystemUtils.wrap(os);

    final processUtils = ProcessUtils(
      processManager: processManager,
      logger: logger,
    );

    if (platform.isMacOS || platform.isLinux) {
      fpiOs = TarXzCompatibleOsUtils(
        os: fpiOs,
        processUtils: processUtils,
      );
    }

    if (platform.isLinux) {
      fpiOs = FPiLinuxOsUtils(
        delegate: fpiOs,
        processUtils: processUtils,
        logger: logger,
      );
    }

    return fpiOs;
  }

  factory FPiOperatingSystemUtils.wrap(OperatingSystemUtils os) => OperatingSystemUtilsFPiWrapper(os: os);

  FPiHostPlatform get fpiHostPlatform;
}

class OperatingSystemUtilsFPiWrapper implements FPiOperatingSystemUtils {
  OperatingSystemUtilsFPiWrapper({
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
  FPiHostPlatform get fpiHostPlatform {
    return switch (hostPlatform) {
      HostPlatform.darwin_x64 => FPiHostPlatform.darwinX64,
      HostPlatform.darwin_arm64 => FPiHostPlatform.darwinARM64,
      HostPlatform.linux_x64 => FPiHostPlatform.linuxX64,
      HostPlatform.linux_arm64 => FPiHostPlatform.linuxARM64,
      HostPlatform.windows_x64 => FPiHostPlatform.windowsX64,
      HostPlatform.windows_arm64 => FPiHostPlatform.windowsARM64,
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
  void unpack(File gzippedTarFile, Directory targetDirectory) {
    return os.unpack(gzippedTarFile, targetDirectory);
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

class DelegateFPiOperatingSystemUtils implements FPiOperatingSystemUtils {
  DelegateFPiOperatingSystemUtils({
    required FPiOperatingSystemUtils delegate,
  }) : _delegate = delegate;

  final FPiOperatingSystemUtils _delegate;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    return _delegate.chmod(entity, mode);
  }

  @override
  Future<int> findFreePort({bool ipv6 = false}) {
    return _delegate.findFreePort(ipv6: ipv6);
  }

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) {
    return _delegate.gzipLevel1Stream(stream);
  }

  @override
  HostPlatform get hostPlatform => _delegate.hostPlatform;

  @override
  FPiHostPlatform get fpiHostPlatform => _delegate.fpiHostPlatform;

  @override
  void makeExecutable(File file) => _delegate.makeExecutable(file);

  @override
  File makePipe(String path) => _delegate.makePipe(path);

  @override
  String get name => _delegate.name;

  @override
  String get pathVarSeparator => _delegate.pathVarSeparator;

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory) {
    return _delegate.unpack(gzippedTarFile, targetDirectory);
  }

  @override
  void unzip(File file, Directory targetDirectory) {
    return _delegate.unzip(file, targetDirectory);
  }

  @override
  File? which(String execName) {
    return _delegate.which(execName);
  }

  @override
  List<File> whichAll(String execName) {
    return _delegate.whichAll(execName);
  }

  @override
  int? getDirectorySize(Directory directory) {
    return _delegate.getDirectorySize(directory);
  }
}

class TarXzCompatibleOsUtils extends DelegateFPiOperatingSystemUtils {
  TarXzCompatibleOsUtils({
    required FPiOperatingSystemUtils os,
    required ProcessUtils processUtils,
  })  : _processUtils = processUtils,
        super(delegate: os);

  final ProcessUtils _processUtils;

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory) {
    _processUtils.runSync(
      <String>['tar', '-xf', gzippedTarFile.path, '-C', targetDirectory.path],
      throwOnError: true,
    );
  }
}

class FPiLinuxOsUtils extends DelegateFPiOperatingSystemUtils {
  FPiLinuxOsUtils({
    required super.delegate,
    required ProcessUtils processUtils,
    required Logger logger,
  })  : _processUtils = processUtils,
        _logger = logger;

  final ProcessUtils _processUtils;
  final Logger _logger;

  FPiHostPlatform _findHostPlatform() {
    final result = _processUtils.runSync(<String>['uname', '-m']);
    // On x64 stdout is "uname -m: x86_64"
    // On arm64 stdout is "uname -m: aarch64, arm64_v8a"
    if (result.exitCode != 0) {
      _logger.printError(
        'Encountered an error trying to run "uname -m":\n'
        '  exit code: ${result.exitCode}\n'
        '  stdout: ${result.stdout.trimRight()}\n'
        '  stderr: ${result.stderr.trimRight()}\n'
        'Assuming host platform is ${FPiHostPlatform.linuxX64}.',
      );
      return FPiHostPlatform.linuxX64;
    }

    final machine = result.stdout.trim();

    if (machine.endsWith('x86_64')) {
      return FPiHostPlatform.linuxX64;
    } else if (machine == 'aarch64' || machine == 'arm64') {
      return FPiHostPlatform.linuxARM64;
    } else if (machine == 'armv7l' || machine == 'arm') {
      return FPiHostPlatform.linuxARM;
    } else {
      _logger.printError(
        'Unrecognized host platform: uname -m: $machine\n'
        'Assuming host platform is ${FPiHostPlatform.linuxX64}.',
      );
      return FPiHostPlatform.linuxX64;
    }
  }

  @override
  late final FPiHostPlatform fpiHostPlatform = _findHostPlatform();
}
