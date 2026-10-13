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

  test('emulator apps use exactly the same demo Firebase project as CI seed', () {
    final main = File('lib/main.dart').readAsStringSync();
    final seed = File('tools/release/start_demo_emulators.sh')
        .readAsStringSync();
    expect(main, contains('if (FirebaseRuntimeConfig.useEmulators)'));
    expect(
      main,
      contains("Firebase.initializeApp(demoProjectId: 'demo-rokter-badhon')"),
    );
    expect(main, contains('DefaultFirebaseOptions.currentPlatform'));
    expect(seed, contains('project="demo-rokter-badhon"'));
    expect(seed, contains('seed-test-admin --project-id'));
  });

  test('emulator bootstrap fails closed without production fallback', () {
    final main = File('lib/main.dart').readAsStringSync();
    final start = main.indexOf('if (FirebaseRuntimeConfig.useEmulators)');
    final end = main.indexOf('Get.put(await LocalizationController.create()');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final bootstrap = main.substring(start, end);
    expect(bootstrap, contains("demoProjectId: 'demo-rokter-badhon'"));
    expect(bootstrap, contains('Duration(seconds: 15)'));
    expect(bootstrap, contains('Demo Firebase initialization unavailable'));
    expect(bootstrap, contains('Demo Firebase emulator unavailable'));
    expect(bootstrap, contains('return;'));
    expect(bootstrap, contains('DefaultFirebaseOptions.currentPlatform'));
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
