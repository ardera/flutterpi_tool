import 'package:file/file.dart';
import 'package:flutterpi_tool/src/archive.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:test/fake.dart';

class FakeOperatingSystemUtils extends Fake implements fl.OperatingSystemUtils {
  FakeOperatingSystemUtils({this.hostPlatform = fl.HostPlatform.linux_x64});

  final List<List<String>> chmods = <List<String>>[];

  @override
  void makeExecutable(File file) {}

  @override
  fl.HostPlatform hostPlatform = fl.HostPlatform.linux_x64;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    chmods.add(<String>[entity.path, mode]);
  }

  @override
  File? which(String execName) => null;

  @override
  List<File> whichAll(String execName) => <File>[];

  @override
  int? getDirectorySize(Directory directory) => 10000000; // 10 MB / 9.5 MiB

  @override
  void unzip(File file, Directory targetDirectory) {}

  @override
  void unpack(File gzippedTarFile, Directory targetDirectory) {}

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) => stream;

  @override
  String get name => 'fake OS name and version';

  @override
  String get pathVarSeparator => ';';

  @override
  Future<int> findFreePort({bool ipv6 = false}) async => 12345;
}

class FakeMoreOperatingSystemUtils extends Fake
    implements MoreOperatingSystemUtils {
  FakeMoreOperatingSystemUtils({
    this.hostPlatform = fl.HostPlatform.linux_x64,
    this.fpiHostPlatform = FlutterpiHostPlatform.linuxX64,
  });

  final List<List<String>> chmods = <List<String>>[];

  @override
  void makeExecutable(File file) {}

  @override
  fl.HostPlatform hostPlatform;

  @override
  void chmod(FileSystemEntity entity, String mode) {
    chmods.add(<String>[entity.path, mode]);
  }

  @override
  File? which(String execName) => null;

  @override
  List<File> whichAll(String execName) => <File>[];

  @override
  int? getDirectorySize(Directory directory) => 10000000; // 10 MB / 9.5 MiB

  @override
  void unzip(File file, Directory targetDirectory) {}

  @override
  void unpack(
    File gzippedTarFile,
    Directory targetDirectory, {
    Archive Function(File)? decoder,
    ArchiveType? type,
  }) {}

  @override
  Stream<List<int>> gzipLevel1Stream(Stream<List<int>> stream) => stream;

  @override
  String get name => 'fake OS name and version';

  @override
  String get pathVarSeparator => ';';

  @override
  Future<int> findFreePort({bool ipv6 = false}) async => 12345;

  @override
  final FlutterpiHostPlatform fpiHostPlatform;
}
