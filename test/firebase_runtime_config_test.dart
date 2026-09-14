import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('emulator routing is explicit and production remains the default', () {
    final source = File(
      'lib/config/firebase_runtime_config.dart',
    ).readAsStringSync();
    expect(source, contains("'USE_FIREBASE_EMULATOR'"));
    expect(source, contains('defaultValue: false'));
    expect(source, contains('if (!useEmulators) return'));
    expect(source, contains('useAuthEmulator'));
    expect(source, contains('useFirestoreEmulator'));
    expect(source, isNot(contains('passwordForAuth')));
    expect(source, isNot(contains('testCredential')));
  });
}
