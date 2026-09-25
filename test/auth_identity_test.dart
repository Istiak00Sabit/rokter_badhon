import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/services/auth_identity.dart';

void main() {
  test('normalizes local and Bangladesh international phone forms', () {
    expect(AuthIdentity.normalizePhone('01712-345678'), '01712345678');
    expect(AuthIdentity.normalizePhone('+8801712345678'), '01712345678');
    expect(AuthIdentity.normalizePhone('8801712345678'), '01712345678');
  });

  test('same phone always derives the same reserved identity', () {
    expect(
      AuthIdentity.internalEmailForPhone('01712 345678'),
      AuthIdentity.internalEmailForPhone('+8801712345678'),
    );
    expect(
      AuthIdentity.internalEmailForPhone('01712345678'),
      'p01712345678@auth.rokterbadhon.internal',
    );
  });

  test('different normalized phones cannot collide', () {
    expect(
      AuthIdentity.internalEmailForPhone('01712345678'),
      isNot(AuthIdentity.internalEmailForPhone('01712345679')),
    );
  });

  test('invalid phone fails closed', () {
    expect(() => AuthIdentity.normalizePhone('not-a-phone'), throwsFormatException);
  });
}
