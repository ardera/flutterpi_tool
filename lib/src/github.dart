// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io' as io;
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

extension _AsyncPutIfAbsent<K, V> on Map<K, V> {
  Future<V> asyncPutIfAbsent(K key, FutureOr<V> Function() ifAbsent) async {
    if (containsKey(key)) {
      return this[key] as V;
    }

    return this[key] = await ifAbsent();
  }
}

class GithubArtifact {
  GithubArtifact({
    required this.name,
    required this.archiveDownloadUrl,
  });

  final String name;
  final Uri archiveDownloadUrl;

  static GithubArtifact fromJson(Map<String, dynamic> json) {
    return GithubArtifact(
      name: json['name'],
      archiveDownloadUrl: Uri.parse(json['archive_download_url']),
    );
  }
}

abstract class MyGithub {
  MyGithub.generative();

  factory MyGithub({
    http.Client? httpClient,
    gh.Authentication? auth,
  }) = MyGithubImpl;

  factory MyGithub.caching({
    http.Client? httpClient,
    gh.Authentication? auth,
  }) {
    return CachingGithub(
      github: MyGithub(httpClient: httpClient, auth: auth),
    );
  }

  factory MyGithub.wrapCaching({
    required MyGithub github,
  }) = CachingGithub;

  Future<gh.Release> getLatestRelease(gh.RepositorySlug repo);

  Future<gh.Release> getReleaseByTagName(
    String tagName, {
    required gh.RepositorySlug repo,
  });

  Future<List<GithubArtifact>> getWorkflowRunArtifacts({
    required gh.RepositorySlug repo,
    required int runId,
    String? nameFilter,
  });

  Future<GithubArtifact?> getWorkflowRunArtifact(
    String name, {
    required gh.RepositorySlug repo,
    required int runId,
  }) async {
    final artifacts = await getWorkflowRunArtifacts(
      repo: repo,
      runId: runId,
      nameFilter: name,
    );
    return artifacts.singleOrNull;
  }

  void authenticate(io.HttpClientRequest request);

  gh.GitHub get github;

  gh.Authentication get auth;

  http.Client get client;
}

class MyGithubImpl extends MyGithub {
  MyGithubImpl({
    http.Client? httpClient,
    gh.Authentication? auth,
  })  : github = gh.GitHub(
          client: httpClient ?? http.Client(),
          auth: auth ?? gh.Authentication.anonymous(),
        ),
        super.generative();

  @override
  final gh.GitHub github;

  @override
  Future<gh.Release> getLatestRelease(gh.RepositorySlug repo) async {
    return await github.repositories.getLatestRelease(repo);
  }

  @override
  Future<gh.Release> getReleaseByTagName(
    String tagName, {
    required gh.RepositorySlug repo,
  }) async {
    return await github.repositories.getReleaseByTagName(repo, tagName);
  }

  @visibleForTesting
  String workflowRunArtifactsUrlPath(gh.RepositorySlug repo, int runId) {
    return '/repos/${repo.fullName}/actions/runs/$runId/artifacts';
  }

  @override
  Future<List<GithubArtifact>> getWorkflowRunArtifacts({
    required gh.RepositorySlug repo,
    required int runId,
    String? nameFilter,
  }) async {
    final path = workflowRunArtifactsUrlPath(repo, runId);

    final response = await github.getJSON(path);

    final results = <GithubArtifact>[];
    for (final artifact in response['artifacts']) {
      results.add(GithubArtifact.fromJson(artifact));
    }

    return results;
  }

  @override
  void authenticate(io.HttpClientRequest request) {
    if (github.auth.authorizationHeaderValue() case String header) {
      request.headers.add('Authorization', header);
    }
  }

  @override
  gh.Authentication get auth => github.auth;

  @override
  http.Client get client => github.client;
}

class CachingGithub extends MyGithub {
  CachingGithub({
    required MyGithub github,
  })  : myGithub = github,
        super.generative();

  final MyGithub myGithub;

  final _latestReleaseCache = <gh.RepositorySlug, gh.Release>{};
  final _releaseByTagNameCache = <String, gh.Release>{};
  final _workflowRunArtifactsCache = <String, List<GithubArtifact>>{};

  @override
  Future<gh.Release> getLatestRelease(gh.RepositorySlug repo) async {
    return await _latestReleaseCache.asyncPutIfAbsent(
      repo,
      () => myGithub.getLatestRelease(repo),
    );
  }

  @override
  Future<gh.Release> getReleaseByTagName(
    String tagName, {
    required gh.RepositorySlug repo,
  }) async {
    return await _releaseByTagNameCache.asyncPutIfAbsent(
      tagName,
      () => myGithub.getReleaseByTagName(tagName, repo: repo),
    );
  }

  @override
  Future<List<GithubArtifact>> getWorkflowRunArtifacts({
    required gh.RepositorySlug repo,
    required int runId,
    String? nameFilter,
  }) async {
    final key = '${repo.fullName}/$runId';
    return _workflowRunArtifactsCache.asyncPutIfAbsent(
      key,
      () => myGithub.getWorkflowRunArtifacts(
        repo: repo,
        runId: runId,
        nameFilter: nameFilter,
      ),
    );
  }

  @override
  void authenticate(io.HttpClientRequest request) {
    myGithub.authenticate(request);
  }

  @override
  gh.GitHub get github => myGithub.github;

  @override
  gh.Authentication get auth => myGithub.auth;

  @override
  http.Client get client => myGithub.client;
}
