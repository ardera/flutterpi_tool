import 'package:archive/src/archive.dart';
import 'package:file/src/interface/directory.dart';
import 'package:file/src/interface/file.dart';
import 'package:file/src/interface/file_system_entity.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:test/expect.dart';

class MockMoreOperatingSystemUtils implements MoreOperatingSystemUtils {
  MockMoreOperatingSystemUtils({
    this.hostPlatform = HostPlatform.linux_x64,
    this.fpiHostPlatform = FlutterpiHostPlatform.linuxX64,
    this.name = 'test',
    this.pathVarSeparator = '/',
  })  : chmodFn = ((_, __) {}),
        findFreePortFn = (({bool ipv6 = false}) async => 1234),
        getDirectorySizeFn = ((_) => null),
        makeExecutableFn = ((_) {}),
        unpackFn = ((
          File gzippedTarFile,
          Directory targetDirectory, {
          ArchiveType? type,
          Archive Function(File p1)? decoder,
        }) {}),
        unzipFn = ((_, __) {}),
        whichFn = ((_) => null),
        whichAllFn = ((_) => []);

  MockMoreOperatingSystemUtils.empty({
    this.hostPlatform = HostPlatform.linux_x64,
    this.fpiHostPlatform = FlutterpiHostPlatform.linuxX64,
    this.name = 'test',
    this.pathVarSeparator = '/',
  });

  void Function(FileSystemEntity entity, String mode)? chmodFn;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    if (chmodFn == null) {
      fail('Expected chmod to not be called.');
    }
    chmodFn!(entity, mode);
  }

  Future<int> Function({bool ipv6})? findFreePortFn;

  @override
  Future<int> findFreePort({bool ipv6 = false}) {
    if (findFreePortFn == null) {
      fail('Expected findFreePort to not be called.');
    }
    return findFreePortFn!(ipv6: ipv6);
  }

  @override
  FlutterpiHostPlatform fpiHostPlatform = FlutterpiHostPlatform.linuxX64;

  int? Function(Directory directory)? getDirectorySizeFn;

  @override
  int? getDirectorySize(Directory directory) {
    if (getDirectorySizeFn == null) {
      fail('Expected getDirectorySize to not be called.');
    }
    return getDirectorySizeFn!(directory);
  }

  Stream<List<int>> Function(Stream<List<int>> stream)? gzipLevel1StreamFn;

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) {
    if (gzipLevel1StreamFn == null) {
      fail('Expected gzipLevel1Stream to not be called.');
    }
    return gzipLevel1StreamFn!(stream);
  }

  @override
  HostPlatform hostPlatform = HostPlatform.linux_x64;

  void Function(File file)? makeExecutableFn;

  @override
  void makeExecutable(File file) {
    if (makeExecutableFn == null) {
      fail('Expected makeExecutable to not be called.');
    }
    makeExecutableFn!(file);
  }

  File Function(String path)? makePipeFn;

  @override
  File makePipe(String path) {
    if (makePipeFn == null) {
      fail('Expected makePipe to not be called.');
    }
    return makePipeFn!(path);
  }

  @override
  String name = 'fake OS name and version';

  @override
  String pathVarSeparator = ';';

  void Function(
    File gzippedTarFile,
    Directory targetDirectory, {
    ArchiveType? type,
    Archive Function(File p1)? decoder,
  })? unpackFn;

  @override
  void unpack(
    File gzippedTarFile,
    Directory targetDirectory, {
    ArchiveType? type,
    Archive Function(File p1)? decoder,
  }) {
    if (unpackFn == null) {
      fail('Expected unpack to not be called.');
    }
    unpackFn!(
      gzippedTarFile,
      targetDirectory,
      type: type,
      decoder: decoder,
    );
  }

  void Function(File file, Directory targetDirectory)? unzipFn;

  @override
  void unzip(File file, Directory targetDirectory) {
    if (unzipFn == null) {
      fail('Expected unzip to not be called.');
    }
    unzipFn!(file, targetDirectory);
  }

  File? Function(String path)? whichFn;

  @override
  File? which(String execName) {
    if (whichFn == null) {
      fail('Expected which to not be called.');
    }
    return whichFn!(execName);
  }

  List<File> Function(String execName)? whichAllFn;

  @override
  List<File> whichAll(String execName) {
    if (whichAllFn == null) {
      fail('Expected whichAll to not be called.');
    }
    return whichAllFn!(execName);
  }
}
