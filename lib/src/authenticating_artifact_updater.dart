// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io' as io;
import 'package:file/file.dart';
import 'package:flutterpi_tool/src/cache.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:meta/meta.dart';

@visibleForTesting
String legalizePath(Uri url, FileSystem fileSystem) {
  final pieces = [url.host, ...url.pathSegments];
  final convertedPieces = pieces.map(_legalizeName);
  return fileSystem.path.joinAll(convertedPieces);
}

String _legalizeName(String fileName) {
  const substitutions = {
    r'@': '@@',
    r'/': '@s@',
    r'\': '@bs@',
    r':': '@c@',
    r'%': '@per@',
    r'*': '@ast@',
    r'<': '@lt@',
    r'>': '@gt@',
    r'"': '@q@',
    r'|': '@pip@',
    r'?': '@ques@',
  };

  final replaced = [
    for (final codeUnit in fileName.codeUnits)
      if (substitutions[String.fromCharCode(codeUnit)] case String substitute) ...substitute.codeUnits else codeUnit
  ];

  return String.fromCharCodes(replaced);
}

class AuthenticatingArtifactUpdater implements ArtifactUpdater {
  AuthenticatingArtifactUpdater({
    required OperatingSystemUtils operatingSystemUtils,
    required Logger logger,
    required FileSystem fileSystem,
    required Directory tempStorage,
    required io.HttpClient httpClient,
    required Platform platform,
    required List<String> allowedBaseUrls,
  })  : _operatingSystemUtils = operatingSystemUtils,
        _httpClient = httpClient,
        _logger = logger,
        _fileSystem = fileSystem,
        _tempStorage = tempStorage,
        _allowedBaseUrls = allowedBaseUrls;

  static const int _kRetryCount = 2;

  final Logger _logger;
  final OperatingSystemUtils _operatingSystemUtils;
  final FileSystem _fileSystem;
  final Directory _tempStorage;
  final io.HttpClient _httpClient;

  final List<String> _allowedBaseUrls;

  @override
  @visibleForTesting
  final List<File> downloadedFiles = <File>[];

  static const Set<String> _denylistedBasenames = <String>{'entitlements.txt', 'without_entitlements.txt'};
  void _removeDenylistedFiles(Directory directory) {
    for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      if (_denylistedBasenames.contains(entity.basename)) {
        entity.deleteSync();
      }
    }
  }

  @override
  Future<void> downloadZipArchive(
    String message,
    Uri url,
    Directory location, {
    void Function(io.HttpClientRequest)? authenticate,
  }) {
    return _downloadArchive(
      message,
      url,
      location,
      _operatingSystemUtils.unzip,
      authenticate: authenticate,
    );
  }

  @override
  Future<void> downloadZippedTarball(
    String message,
    Uri url,
    Directory location, {
    void Function(io.HttpClientRequest)? authenticate,
  }) {
    return _downloadArchive(
      message,
      url,
      location,
      _operatingSystemUtils.unpack,
      authenticate: authenticate,
    );
  }

  Future<void> _downloadArchive(
    String message,
    Uri url,
    Directory location,
    void Function(File, Directory) extractor, {
    void Function(io.HttpClientRequest)? authenticate,
  }) async {
    final downloadPath = legalizePath(url, _fileSystem);
    final tempFile = _createDownloadFile(downloadPath);

    var tries = _kRetryCount;
    while (tries > 0) {
      final status = _logger.startProgress(message);

      try {
        ErrorHandlingFileSystem.deleteIfExists(tempFile);
        if (!tempFile.parent.existsSync()) {
          tempFile.parent.createSync(recursive: true);
        }

        await _download(url, tempFile, status, authenticate: authenticate);

        if (!tempFile.existsSync()) {
          throw Exception('Did not find downloaded file ${tempFile.path}');
        }
      } on Exception catch (err) {
        _logger.printTrace(err.toString());
        tries -= 1;

        if (tries == 0) {
          throwToolExit('Failed to download $url. Ensure you have network connectivity and then try again.\n$err');
        }
        continue;
      } finally {
        status.stop();
      }

      final destination = location.childDirectory(tempFile.fileSystem.path.basenameWithoutExtension(tempFile.path));

      ErrorHandlingFileSystem.deleteIfExists(destination, recursive: true);
      location.createSync(recursive: true);

      try {
        extractor(tempFile, location);
      } on Exception catch (err) {
        tries -= 1;
        if (tries == 0) {
          throwToolExit(
            'Flutter could not download and/or extract $url. Ensure you have '
            'network connectivity and all of the required dependencies listed at '
            'flutter.dev/setup.\nThe original exception was: $err.',
          );
        }

        ErrorHandlingFileSystem.deleteIfExists(tempFile);
        continue;
      }

      _removeDenylistedFiles(location);
      return;
    }
  }

  Future<void> _download(Uri url, File file, Status status, {void Function(io.HttpClientRequest)? authenticate}) async {
    final allowed = _allowedBaseUrls.any((baseUrl) => url.toString().startsWith(baseUrl));

    // In tests make this a hard failure.
    assert(
      allowed,
      'URL not allowed: $url\n'
      'Allowed URLs must be based on one of: ${_allowedBaseUrls.join(', ')}',
    );

    // In production, issue a warning but allow the download to proceed.
    if (!allowed) {
      status.pause();
      _logger.printWarning(
          'Downloading an artifact that may not be reachable in some environments (e.g. firewalled environments): $url\n'
          'This should not have happened. This is likely a Flutter SDK bug. Please file an issue at https://github.com/flutter/flutter/issues/new?template=1_activation.yml');
      status.resume();
    }

    final request = await _httpClient.getUrl(url);

    if (authenticate != null) {
      try {
        authenticate(request);
      } finally {
        request.close().ignore();
      }
    }

    final response = await request.close();

    if (response.statusCode != io.HttpStatus.ok) {
      throw Exception(response.statusCode);
    }

    final handle = file.openSync(mode: FileMode.writeOnly);
    try {
      await for (final chunk in response) {
        handle.writeFromSync(chunk);
      }
    } finally {
      handle.closeSync();
    }
  }

  File _createDownloadFile(String name) {
    final path = _fileSystem.path.join(_tempStorage.path, name);
    final file = _fileSystem.file(path);
    downloadedFiles.add(file);
    return file;
  }

  @override
  void removeDownloadedFiles() {
    for (final file in downloadedFiles) {
      ErrorHandlingFileSystem.deleteIfExists(file);

      for (var directory = file.parent;
          directory.absolute.path != _tempStorage.absolute.path;
          directory = directory.parent) {
        // Handle race condition when the directory is deleted before this step

        if (directory.existsSync() && directory.listSync().isEmpty) {
          ErrorHandlingFileSystem.deleteIfExists(directory, recursive: true);
        }
      }
    }
  }
}
