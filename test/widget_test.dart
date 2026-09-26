import 'package:flutter_test/flutter_test.dart';
import 'package:subbox_app/utils/validators.dart';

void main() {
  test('validators', () {
    expect(validateEmail('bad'), isNotNull);
    expect(validateEmail('user@example.com'), isNull);
    expect(validatePassword('123'), isNotNull);
    expect(validatePassword('123456'), isNull);
    expect(validateName('Javeria'), isNull);
  });
}
