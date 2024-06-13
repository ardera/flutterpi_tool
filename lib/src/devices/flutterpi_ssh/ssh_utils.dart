import 'dart:async';
import 'dart:io';
import 'package:flutterpi_tool/src/fltool/common.dart';

class SshException implements Exception {
  SshException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SshUtils {
  SshUtils({
    required this.processUtils,
    this.sshExecutable = 'ssh',
    this.scpExecutable = 'scp',
    required this.defaultRemote,
  });

  final String sshExecutable;
  final String scpExecutable;
  final String defaultRemote;
  final ProcessUtils processUtils;

  List<String> buildSshCommand({
    bool? interactive = false,
    bool? allocateTTY,
    bool? exitOnForwardFailure,
    Iterable<(int, int)> remotePortForwards = const [],
    Iterable<(int, int)> localPortForwards = const [],
    Iterable<String> extraArgs = const [],
    String? remote,
    String? command,
  }) {
    remote ??= defaultRemote;

    return <String>[
      sshExecutable,
      if (interactive != null) ...[
        '-o',
        'BatchMode=${interactive ? 'no' : 'yes'}',
      ],
      if (allocateTTY == true) '-tt',
      if (exitOnForwardFailure == true) ...[
        '-o',
        'ExitOnForwardFailure=yes'
      ] else if (exitOnForwardFailure == false) ...[
        '-o',
        'ExitOnForwardFailure=no'
      ],
      for (final (local, remote) in localPortForwards) ...[
        '-L',
        '$local:localhost:$remote',
      ],
      for (final (remote, local) in remotePortForwards) ...[
        '-R',
        '$local:localhost:$remote',
      ],
      if (command == null) '-T',
      ...extraArgs,
      remote,
      if (command != null) command,
    ];
  }

  List<String> buildUsermodAddGroupsCommand(Iterable<String> groups) {
    if (groups.isEmpty) throw ArgumentError.value(groups, 'groups', 'Groups must not be empty.');

    return ['usermod', '-aG', groups.join(','), r'$USER'];
  }

  Future<RunResult> runSsh({
    String? remote,
    String? command,
    Iterable<String> extraArgs = const [],
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
    bool? allocateTTY,
    Iterable<(int, int)> localPortForwards = const [],
    Iterable<(int, int)> remotePortForwards = const [],
    bool? exitOnForwardFailure,
  }) {
    remote ??= defaultRemote;

    final cmd = buildSshCommand(
      allocateTTY: allocateTTY,
      exitOnForwardFailure: exitOnForwardFailure,
      localPortForwards: localPortForwards,
      extraArgs: extraArgs,
      remote: remote,
      command: command,
    );

    try {
      return processUtils.run(
        cmd,
        throwOnError: throwOnError,
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: timeout,
        timeoutRetries: timeoutRetries,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 255:
          throw SshException('SSH to "$remote" failed: $e');
        default:
          throw SshException('Remote command failed: $e');
      }
    }
  }

  Future<Process> startSsh({
    String? remote,
    String? command,
    Iterable<String> extraArgs = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    bool? allocateTTY,
    Iterable<(int, int)> remotePortForwards = const [],
    Iterable<(int, int)> localPortForwards = const [],
    bool? exitOnForwardFailure,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    remote ??= defaultRemote;

    final cmd = buildSshCommand(
      allocateTTY: allocateTTY,
      exitOnForwardFailure: exitOnForwardFailure,
      localPortForwards: localPortForwards,
      extraArgs: extraArgs,
      remote: remote,
      command: command,
    );

    try {
      return processUtils.start(
        cmd,
        workingDirectory: workingDirectory,
        environment: environment,
        mode: mode,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 255:
          throw SshException('SSH to "$remote" failed: $e');
        default:
          throw SshException('Remote command failed: $e');
      }
    }
  }

  Future<RunResult> scp({
    String? remote,
    required String localPath,
    required String remotePath,
    Iterable<String> extraArgs = const [],
    bool throwOnError = false,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    int timeoutRetries = 0,
    bool recursive = true,
  }) {
    remote ??= defaultRemote;

    try {
      return processUtils.run(
        [
          scpExecutable,
          '-o',
          'BatchMode=yes',
          if (recursive) '-r',
          ...extraArgs,
          localPath,
          '$remote:$remotePath',
        ],
        throwOnError: throwOnError,
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: timeout,
        timeoutRetries: timeoutRetries,
      );
    } on ProcessException catch (e) {
      switch (e.errorCode) {
        case 255:
          throw SshException('SSH to remote "$remote" failed: $e');
        default:
          throw SshException('Remote command failed: $e');
      }
    }
  }

  Future<bool> tryConnect({
    Duration? timeout,
    bool throwOnError = false,
  }) async {
    final timeoutSecondsCeiled = switch (timeout) {
      Duration(inMicroseconds: final micros) =>
        (micros + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond,
      _ => null,
    };

    final result = await runSsh(
      command: null,
      extraArgs: [
        if (timeoutSecondsCeiled != null) ...[
          '-o',
          'ConnectTimeout=$timeoutSecondsCeiled',
        ],
      ],
      throwOnError: throwOnError,
    );

    if (result.exitCode == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> copy({
    required String localPath,
    required String remotePath,
    String? remote,
  }) {
    return scp(
      localPath: localPath,
      remotePath: remotePath,
      remote: remote,
      throwOnError: true,
      recursive: true,
    );
  }

  Future<String> uname({Iterable<String>? args, Duration? timeout}) async {
    final command = ['uname', ...?args].join(' ');

    final result = await runSsh(
      command: command,
      throwOnError: true,
      timeout: timeout,
    );

    return result.stdout.trim();
  }

  Future<String> id({Iterable<String>? args, Duration? timeout}) async {
    final command = ['id', ...?args].join(' ');

    final result = await runSsh(
      command: command,
      throwOnError: true,
      timeout: timeout,
    );

    return result.stdout.trim();
  }

  Future<bool> remoteUserBelongsToGroups(Iterable<String> groups) async {
    final result = await id(args: ['-nG']);
    final userGroups = result.split(' ');
    return groups.every(userGroups.contains);
  }
}
