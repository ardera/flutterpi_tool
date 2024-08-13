import 'package:flutterpi_tool/src/github.dart';
import 'package:github/github.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'github_test_api_output.dart';

void main() {
  test('workflow artifacts querying', () async {
    final client = MockClient((request) async {
      final uri1 =
          'https://api.github.com/repos/ardera/flutter-ci/actions/runs/10332084071/artifacts?page=1&per_page=100';

      final uri2 =
          'https://api.github.com/repos/ardera/flutter-ci/actions/runs/10332084071/artifacts?page=2&per_page=100';

      expect(
        request.url.toString(),
        anyOf(equals(uri1), equals(uri2)),
      );

      if (request.url.queryParameters['page'] == '1') {
        return Response(
          githubWorkflowRunArtifactsPage1,
          200,
          headers: {
            'Content-Type': 'application/json',
          },
        );
      } else {
        expect(request.url.queryParameters['page'], '2');
        return Response(
          githubWorkflowRunArtifactsPage2,
          200,
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }
    });

    final github = MyGithub(
      httpClient: client,
    );

    final artifact = await github.getWorkflowRunArtifact(
      'universal',
      repo: RepositorySlug('ardera', 'flutter-ci'),
      runId: 10332084071,
    );

    expect(artifact, isNotNull);
    artifact!;

    expect(artifact.name, 'universal');

    expect(artifact.archiveDownloadUrl, isNotNull);
    expect(
      artifact.archiveDownloadUrl.toString(),
      'https://api.github.com/repos/ardera/flutter-ci/actions/artifacts/1797913057/zip',
    );
  });
}
