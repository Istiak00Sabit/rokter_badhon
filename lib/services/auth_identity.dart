/// Phone-based Firebase Auth identity helpers.
///
/// Firebase's password provider accepts an email-shaped identifier. The
/// application derives a private, deterministic identifier from the
/// normalized organization phone number. It is never a public profile email
/// and must not be copied into Firestore profile fields.
class AuthIdentity {
  static const internalDomain = 'auth.rokterbadhon.internal';

  const AuthIdentity._();

  static String normalizePhone(String value) {
    var phone = value.trim();
    if (phone.isEmpty) throw const FormatException('Phone number is required.');

    const bengaliDigits = '\u09e6\u09e7\u09e8\u09e9\u09ea\u09eb\u09ec\u09ed\u09ee\u09ef';
    const latinDigits = '0123456789';
    for (var index = 0; index < bengaliDigits.length; index++) {
      phone = phone.replaceAll(bengaliDigits[index], latinDigits[index]);
    }
    phone = phone.replaceAll(RegExp(r'[\s().-]'), '');

    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('00880')) phone = phone.substring(2);
    if (phone.startsWith('880')) phone = '0${phone.substring(3)}';

    if (!RegExp(r'^01[0-9]{9}$').hasMatch(phone)) {
      throw const FormatException('Phone number must be a valid Bangladesh number.');
    }
    return phone;
  }

  static String internalEmailForPhone(String phone) {
    return 'p${normalizePhone(phone)}@$internalDomain';
  }
}
