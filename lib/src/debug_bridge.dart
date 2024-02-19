import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:tar/tar.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:http/http.dart' as http;

enum AppStatus {
  notInstalled(false, false),
  installedOnly(true, false),
  installedAndRunning(true, true);

  const AppStatus(this.installed, this.running);

  @override
  String toString() => name;

  final bool installed;
  final bool running;
}

const kAppNameKey = 'name';
const kAppStatusKey = 'status';
const kInstallTimeKey = 'installTime';
const kFlutterPiPathKey = 'flutterpiPath';
const kFlutterPiArgsKey = 'flutterpiArgs';
const kEngineArgsKey = 'engineArgs';
const kStartTimeKey = 'startTime';

class ResponseException implements Exception {
  const ResponseException(this.response);

  final Response response;
}

Middleware catchResponseExceptions = (innerHandler) {
  return (request) {
    return Future.sync(() => innerHandler(request)).catchError(
      (Object error, StackTrace stackTrace) {
        return (error as ResponseException).response;
      },
      test: (error) => error is ResponseException,
    );
  };
};

extension ResponseAsException on Response {
  ResponseException asException() => ResponseException(this);
}

class App {
  App.notInstalled(this.appName) : status = AppStatus.notInstalled;

  App.installed(this.appName) : status = AppStatus.installedOnly;

  String appName;
  AppStatus status;

  DateTime? installTime;
  Directory? installDir;

  String? flutterpiPath;
  Iterable<String>? flutterpiArgs;
  Iterable<String>? engineArgs;
  io.Process? process;
  DateTime? startTime;

  Object? toJson() {
    return {
      kAppNameKey: appName,
      kAppStatusKey: '$status',
      kInstallTimeKey: installTime?.toUtc().toIso8601String(),
      kFlutterPiPathKey: flutterpiPath,
      kFlutterPiArgsKey: flutterpiArgs,
      kEngineArgsKey: engineArgs,
      kStartTimeKey: startTime?.toUtc().toIso8601String(),
    };
  }
}

class DebugBridgeServer {
  DebugBridgeServer({
    this.fs = const LocalFileSystem(),
    this.processManager = const LocalProcessManager(),
  }) : targetDir = fs.systemTempDirectory.childDirectory('flutterpi_debug_bridge');

  final FileSystem fs;
  final Directory targetDir;
  final ProcessManager processManager;

  @visibleForTesting
  final apps = <String, App>{};

  late final router = shelf_router.Router()
    ..post('apps/<name>/bundle', onPostAppBundle)
    ..get('apps/<name>/status', onGetAppStatus)
    ..put('apps/<name>/status', onPutAppStatus)
    ..get('apps/<name>/logs', onGetLogs);

  App getApp(String name) {
    return apps[name] ?? App.notInstalled(name);
  }

  Future<Response> onPostAppBundle(Request request) async {
    final name = request.params['name'];

    final reader = TarReader(request.read());
    while (await reader.moveNext()) {
      final entry = reader.current;

      final destination = targetDir.childFile(entry.name);
      if (fs.path.isWithin(targetDir.path, destination.path)) {
        return Response.badRequest(body: 'Invalid tar entry: ${entry.name}');
      }

      await entry.contents.pipe(destination.openWrite());
    }

    return Response.ok(null);
  }

  Future<void> startApp(
    String appName, {
    Iterable<String> engineArgs = const [],
    Iterable<String> flutterpiArgs = const [],
    String flutterpiPath = 'flutter-pi',
  }) async {
    final app = getApp(appName);

    // If the app is already running, do nothing
    if (app.status == AppStatus.installedAndRunning) {
      return;
    }

    final process = await processManager.start([
      flutterpiPath,
      ...flutterpiArgs,
      targetDir.childDirectory(appName).path,
      ...engineArgs,
    ]);

    app
      ..engineArgs = engineArgs
      ..flutterpiArgs = flutterpiArgs
      ..flutterpiPath = flutterpiPath
      ..process = process
      ..startTime = DateTime.now();
  }

  Future<void> stopApp(String name) async {
    final app = getApp(name);

    if (app.status != AppStatus.installedAndRunning) {
      return;
    }

    // First we kill with
    app.process!.kill();

    try {
      await app.process!.exitCode.timeout(Duration(seconds: 15));
      return;
    } on TimeoutException catch (_) {}

    app.process!.kill(io.ProcessSignal.sigkill);
    await app.process!.exitCode.timeout(Duration(seconds: 15));
  }

  void uninstallApp(String name) {
    final app = getApp(name);

    // if the app is not installed, don't remove it.
    if (app.status == AppStatus.notInstalled) {
      return;
    } else if (app.status == AppStatus.installedAndRunning) {
      throw StateError('App needs to be stopped first before it can be uninstalled.');
    }

    final dir = app.installDir!;

    // delete the install dir.
    dir.deleteSync();

    // remove the app from the index.
    apps.remove(name);
  }

  Future<Response> onGetLogs(Request request) async {
    final appName = request.params['name'] as String;

    final app = getApp(appName);
    if (app.status != AppStatus.installedAndRunning) {
      return Response.badRequest(body: 'App $appName is not running.', encoding: utf8);
    }

    return Response.ok(
      StreamGroup.merge([
        app.process!.stdout,
        app.process!.stderr,
      ]),
      encoding: utf8,
    );
  }

  Future<Response> setAppStatus(
    String appName,
    AppStatus status, {
    String? flutterpiPath,
    Iterable<String>? engineArgs,
    Iterable<String>? flutterpiArgs,
  }) async {
    final session = getApp(appName);

    final oldStatus = session.status;

    if (oldStatus.running && !status.running) {
      await stopApp(appName);
    }

    if (oldStatus.installed && !status.installed) {
      uninstallApp(appName);
    }

    if (!oldStatus.installed && status.installed) {
      return Response.badRequest(body: 'App with name $appName is not installed.', encoding: utf8);
    }

    if (!oldStatus.running && status.running) {
      await startApp(
        appName,
        flutterpiPath: flutterpiPath ?? 'flutter-pi',
        flutterpiArgs: flutterpiArgs ?? [],
        engineArgs: engineArgs ?? [],
      );
    }

    return Response.ok(null);
  }

  Future<Response> onPutAppStatus(Request request) async {
    final name = request.params['name'] as String;

    final body = await request.readAsString();
    final args = jsonDecode(
      body,
      reviver: (key, value) {
        if (key == kAppStatusKey) {
          return AppStatus.values.singleWhere(
            (status) => '$status' == value,
            orElse: () => throw Response.badRequest(body: 'Bad request', encoding: utf8).asException(),
          );
        } else {
          return value;
        }
      },
    );

    if (request.mimeType != 'application/json') {
      return Response.badRequest(body: 'Unsupported Content-Type.', encoding: utf8);
    }

    final status = switch (args) {
      {kAppStatusKey: AppStatus s} => s,
      _ => throw Response.badRequest(body: 'Bad request', encoding: utf8).asException(),
    };

    final flutterpiPath = args[kFlutterPiPathKey] as String?;
    final engineArgs = (args[kEngineArgsKey] as Iterable?)?.cast<String>().toList();
    final flutterpiArgs = (args[kFlutterPiArgsKey] as Iterable?)?.cast<String>().toList();

    return await setAppStatus(
      name,
      status,
      flutterpiPath: flutterpiPath,
      flutterpiArgs: flutterpiArgs,
      engineArgs: engineArgs,
    );
  }

  Response onGetAppStatus(Request request) {
    if (request.mimeType != 'application/json') {
      return Response.badRequest(body: 'Unsupported Content-Type.', encoding: utf8);
    }

    final name = request.params['name'] as String;
    final app = getApp(name);

    return Response.ok(
      jsonEncode(app.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

class DebugBridgeClient {
  DebugBridgeClient({
    required this.host,
    required this.port,
    http.Client? client,
  }) : client = client ?? http.Client();

  final http.Client client;
  final io.InternetAddress host;
  final int port;

  @visibleForTesting
  Uri buildAppBundleURI(String appName) {
    return Uri(
      host: host.address,
      port: port,
      pathSegments: ['apps', appName, 'bundle'],
    );
  }

  @visibleForTesting
  Uri buildAppStatusURI(String appName) {
    return Uri(
      host: host.address,
      port: port,
      pathSegments: ['apps', appName, 'status'],
    );
  }

  @visibleForTesting
  Uri buildAppLogsURI(String appName) {
    return Uri(
      host: host.address,
      port: port,
      pathSegments: ['apps', appName, 'logs'],
    );
  }

  Future<void> uploadBundle(String name, Directory bundle) async {
    final bytes = await tarDirectory(bundle);

    final uri = buildAppBundleURI(name);

    final response = await client.post(
      uri,
      body: bytes,
      headers: {'Content-Type': 'application/x-tar'},
    );

    if (response.statusCode != 200) {
      throw http.ClientException('Request failed: status code: ${response.statusCode}, body: ${response.body}', uri);
    }
  }

  @visibleForTesting
  @protected
  Future<List<int>> tarDirectory(Directory bundle) async {
    final builder = BytesBuilder(copy: false);

    await bundle
        .list(recursive: true)
        .expand((entity) {
          if (entity is File) {
            final stat = entity.statSync();

            /// TODO: This must be changed when we're on windows.
            bundle.fileSystem.path.relative(entity.path, from: bundle.path);

            final entry = TarEntry(
              TarHeader(
                name: entity.basename,
                size: stat.size,
              ),
              entity.openRead(),
            );

            return [entry];
          }

          return [];
        })
        .transform(tarWriter)
        .forEach(builder.add);

    return builder.toBytes();
  }

  @visibleForTesting
  @protected
  Future<void> setAppStatus(
    String name, {
    required AppStatus status,
    String? flutterpiPath,
    Iterable<String>? flutterpiArgs,
    Iterable<String>? engineArgs,
  }) async {
    final uri = buildAppStatusURI(name);

    final json = {
      kAppStatusKey: status,
      kFlutterPiPathKey: flutterpiPath,
      kFlutterPiArgsKey: flutterpiArgs,
      kEngineArgsKey: engineArgs,
    };

    final body = jsonEncode(
      json,
      toEncodable: (nonEncodable) => switch (nonEncodable) {
        AppStatus status => status.toString(),
        dynamic nonEncodable => nonEncodable.toJson(),
      },
    );

    await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  Future<void> uninstallApp(String name) async {
    return await setAppStatus(name, status: AppStatus.notInstalled);
  }

  Future<void> startApp(
    String name, {
    String flutterpiPath = 'flutter-pi',
    Iterable<String> flutterpiArgs = const [],
    Iterable<String> engineArgs = const [],
  }) async {
    return await setAppStatus(
      name,
      status: AppStatus.installedAndRunning,
      flutterpiPath: flutterpiPath,
      flutterpiArgs: flutterpiArgs,
      engineArgs: engineArgs,
    );
  }

  Future<void> stopApp(
    String name,
  ) async {
    return setAppStatus(
      name,
      status: AppStatus.installedOnly,
    );
  }

  Future<Stream<String>> getLogStream(String appName) async {
    final uri = buildAppLogsURI(appName);

    final response = await client.send(http.Request('get', uri));

    final body = response.stream.transform(utf8.decoder);

    return body;
  }
}

void main() async {
  final bridge = DebugBridgeServer();

  final handler =
      Pipeline().addMiddleware(logRequests()).addMiddleware(catchResponseExceptions).addHandler(bridge.router);

  final server = await shelf_io.serve(handler, io.InternetAddress.anyIPv4, 8080);
  final server6 = await shelf_io.serve(handler, io.InternetAddress.anyIPv6, 8080);

  server.autoCompress = true;
  server6.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}, http://${server6.address.host}:${server6.port}');

  await server.last;
  await server6.last;
}
