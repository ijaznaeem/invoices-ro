import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices_ro/services/whiztext_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('gateway credentials remain separate between signed-in users', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = WhizTextCredentials(userId: 'first-account');
    final second = WhizTextCredentials(userId: 'second-account');
    await first.save(' first-key ');
    expect(await first.read(), 'first-key');
    expect(await second.read(), isNull);
    await second.save('second-key');
    await first.clear();
    expect(await first.read(), isNull);
    expect(await second.read(), 'second-key');
    expect(() => second.save('bad\nkey'), throwsArgumentError);
    expect(await second.read(), 'second-key');
  });
}
