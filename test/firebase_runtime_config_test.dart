import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rokter_badhon/config/firebase_runtime_config.dart';

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

  test('physical Android loopback uses the adb-reverse-safe host', () {
    expect(
      FirebaseRuntimeConfig.hostForPlatform(host: '127.0.0.1', android: true),
      '0.0.0.0',
    );
    expect(
      FirebaseRuntimeConfig.hostForPlatform(host: '10.0.2.2', android: true),
      '10.0.2.2',
    );
    expect(
      FirebaseRuntimeConfig.hostForPlatform(host: '127.0.0.1', android: false),
      '127.0.0.1',
    );
  });
}
