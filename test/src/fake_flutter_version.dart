// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Extraced from: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/test/src/fakes.dart

import 'package:file/file.dart';
import 'package:flutterpi_tool/src/fltool/common.dart' as fltool;

class FakeFlutterVersion implements fltool.FlutterVersion {
  FakeFlutterVersion({
    this.branch = 'master',
    this.dartSdkVersion = '12',
    this.devToolsVersion = '2.8.0',
    this.engineRevision = 'abcdefghijklmnopqrstuvwxyz',
    this.engineRevisionShort = 'abcde',
    this.engineAge = '0 hours ago',
    this.engineCommitDate = '12/01/01',
    this.repositoryUrl = 'https://github.com/flutter/flutter.git',
    this.frameworkVersion = '0.0.0',
    this.frameworkRevision = '11111111111111111111',
    this.frameworkRevisionShort = '11111',
    this.frameworkAge = '0 hours ago',
    this.frameworkCommitDate = '12/01/01',
    this.gitTagVersion = const fltool.GitTagVersion.unknown(),
    this.flutterRoot = '/path/to/flutter',
    this.nextFlutterVersion,
    this.engineBuildDate = '12/01/01',
    this.engineContentHash = 'abcdef',
  });

  final String branch;

  bool get didFetchTagsAndUpdate => _didFetchTagsAndUpdate;
  bool _didFetchTagsAndUpdate = false;

  /// Will be returned by [fetchTagsAndGetVersion] if not null.
  final fltool.FlutterVersion? nextFlutterVersion;

  @override
  fltool.FlutterVersion fetchTagsAndGetVersion({
    fltool.SystemClock clock = const fltool.SystemClock(),
  }) {
    _didFetchTagsAndUpdate = true;
    return nextFlutterVersion ?? this;
  }

  bool get didCheckFlutterVersionFreshness => _didCheckFlutterVersionFreshness;
  bool _didCheckFlutterVersionFreshness = false;

  @override
  String get channel {
    if (fltool.kOfficialChannels.contains(branch) ||
        fltool.kObsoleteBranches.containsKey(branch)) {
      return branch;
    }
    return fltool.kUserBranch;
  }

  @override
  final String flutterRoot;

  @override
  final String devToolsVersion;

  @override
  final String dartSdkVersion;

  @override
  final String engineRevision;

  @override
  final String engineRevisionShort;

  @override
  final String? engineCommitDate;

  @override
  final String engineAge;

  @override
  final String? repositoryUrl;

  @override
  final String frameworkVersion;

  @override
  final String frameworkRevision;

  @override
  final String frameworkRevisionShort;

  @override
  final String frameworkAge;

  @override
  final String frameworkCommitDate;

  @override
  final fltool.GitTagVersion gitTagVersion;

  @override
  final String? engineBuildDate;

  @override
  final String? engineContentHash;

  @override
  FileSystem get fs =>
      throw UnimplementedError('FakeFlutterVersion.fs is not implemented');

  @override
  Future<void> checkFlutterVersionFreshness() async {
    _didCheckFlutterVersionFreshness = true;
  }

  @override
  Future<void> ensureVersionFile() async {}

  @override
  String getBranchName({bool redactUnknownBranches = false}) {
    if (!redactUnknownBranches ||
        fltool.kOfficialChannels.contains(branch) ||
        fltool.kObsoleteBranches.containsKey(branch)) {
      return branch;
    }
    return fltool.kUserBranch;
  }

  @override
  String getVersionString({bool redactUnknownBranches = false}) {
    return '${getBranchName(redactUnknownBranches: redactUnknownBranches)}/$frameworkRevision';
  }

  @override
  Map<String, Object> toJson() {
    return <String, Object>{};
  }
}
