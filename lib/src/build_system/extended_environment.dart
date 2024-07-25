import 'package:file/file.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:process/process.dart';
import 'package:unified_analytics/unified_analytics.dart';

class ExtendedEnvironment implements Environment {
  factory ExtendedEnvironment({
    required Directory projectDir,
    required Directory outputDir,
    required Directory cacheDir,
    required Directory flutterRootDir,
    required FileSystem fileSystem,
    required Logger logger,
    required Artifacts artifacts,
    required ProcessManager processManager,
    required Platform platform,
    required Usage usage,
    required Analytics analytics,
    String? engineVersion,
    required bool generateDartPluginRegistry,
    Directory? buildDir,
    required MoreOperatingSystemUtils operatingSystemUtils,
    Map<String, String> defines = const <String, String>{},
    Map<String, String> inputs = const <String, String>{},
  }) {
    return ExtendedEnvironment.wrap(
      operatingSystemUtils: operatingSystemUtils,
      delegate: Environment(
        projectDir: projectDir,
        outputDir: outputDir,
        cacheDir: cacheDir,
        flutterRootDir: flutterRootDir,
        fileSystem: fileSystem,
        logger: logger,
        artifacts: artifacts,
        processManager: processManager,
        platform: platform,
        usage: usage,
        analytics: analytics,
        engineVersion: engineVersion,
        generateDartPluginRegistry: generateDartPluginRegistry,
        buildDir: buildDir,
        defines: defines,
        inputs: inputs,
      ),
    );
  }

  ExtendedEnvironment.wrap({
    required this.operatingSystemUtils,
    required Environment delegate,
  }) : _delegate = delegate;

  final Environment _delegate;

  @override
  Analytics get analytics => _delegate.analytics;

  @override
  Artifacts get artifacts => _delegate.artifacts;

  @override
  Directory get buildDir => _delegate.buildDir;

  @override
  Directory get cacheDir => _delegate.cacheDir;

  @override
  Map<String, String> get defines => _delegate.defines;

  @override
  DepfileService get depFileService => _delegate.depFileService;

  @override
  String? get engineVersion => _delegate.engineVersion;

  @override
  FileSystem get fileSystem => _delegate.fileSystem;

  @override
  Directory get flutterRootDir => _delegate.flutterRootDir;

  @override
  bool get generateDartPluginRegistry => _delegate.generateDartPluginRegistry;

  @override
  Map<String, String> get inputs => _delegate.inputs;

  @override
  Logger get logger => _delegate.logger;

  @override
  Directory get outputDir => _delegate.outputDir;

  @override
  Platform get platform => _delegate.platform;

  @override
  ProcessManager get processManager => _delegate.processManager;

  @override
  Directory get projectDir => _delegate.projectDir;

  @override
  Directory get rootBuildDir => _delegate.rootBuildDir;

  @override
  Usage get usage => _delegate.usage;

  final MoreOperatingSystemUtils operatingSystemUtils;
}
