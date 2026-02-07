import 'package:integration_test/integration_test.dart';
import 'package:hooks_test_package/hooks_test_package.dart' as hooks_test;
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('native hooks sum works', () async {
    expect(hooks_test.sum(2, 1), equals(3));

    await expectLater(hooks_test.sumAsync(2, 1), equals(3));
  });
}
