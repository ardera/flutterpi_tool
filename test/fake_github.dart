import 'dart:io';

import 'package:flutterpi_tool/src/github.dart';
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;

class FakeGithub extends MyGithub {
  FakeGithub() : super.generative();

  @override
  Future<gh.Release> getLatestRelease(gh.RepositorySlug repo) {
    if (getLatestReleaseFn == null) {
      throw UnimplementedError();
    }

    return getLatestReleaseFn!(repo);
  }

  Future<gh.Release> Function(gh.RepositorySlug repo)? getLatestReleaseFn;

  @override
  Future<gh.Release> getReleaseByTagName(
    String tagName, {
    required gh.RepositorySlug repo,
  }) {
    if (getReleaseByTagNameFn == null) {
      throw UnimplementedError();
    }

    return getReleaseByTagNameFn!(tagName, repo: repo);
  }

  Future<gh.Release> Function(
    String tagName, {
    required gh.RepositorySlug repo,
  })? getReleaseByTagNameFn;

  @override
  Future<List<GithubArtifact>> getWorkflowRunArtifacts({
    required gh.RepositorySlug repo,
    required int runId,
    String? nameFilter,
  }) {
    if (getWorkflowRunArtifactsFn == null) {
      throw UnimplementedError();
    }

    return getWorkflowRunArtifactsFn!(
      repo: repo,
      runId: runId,
      nameFilter: nameFilter,
    );
  }

  Future<List<GithubArtifact>> Function({
    required gh.RepositorySlug repo,
    required int runId,
    String? nameFilter,
  })? getWorkflowRunArtifactsFn;

  @override
  void authenticate(HttpClientRequest request) {
    if (authenticateFn == null) {
      throw UnimplementedError();
    }

    authenticateFn!(request);
  }

  void Function(HttpClientRequest request)? authenticateFn;

  @override
  gh.Authentication auth = gh.Authentication.anonymous();

  http.Client? clientFake;

  @override
  http.Client get client {
    if (clientFake != null) {
      return clientFake!;
    }

    throw UnimplementedError();
  }

  @override
  gh.GitHub get github {
    if (githubFake != null) {
      return githubFake!;
    }

    throw UnimplementedError();
  }

  gh.GitHub? githubFake;
}
