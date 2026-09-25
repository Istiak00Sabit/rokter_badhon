import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseRuntimeConfig {
  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );
  static const String emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  static const int authPort = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  static const int firestorePort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );

  const FirebaseRuntimeConfig._();

  // FlutterFire's Android emulator helper rewrites 127.0.0.1 to 10.0.2.2.
  // That address is correct for an Android emulator, but not for a physical
  // phone using `adb reverse`. Keep the public define/documented value at
  // 127.0.0.1 and use the wildcard bind address to preserve the reverse route.
  static String hostForPlatform({required String host, required bool android}) {
    if (android && host == '127.0.0.1') return '0.0.0.0';
    return host;
  }

  static String get connectionHost {
    final android = defaultTargetPlatform == TargetPlatform.android;
    // 10.0.2.2 is only the Android-emulator alias for the host machine. A
    // Chrome/desktop process runs on the host itself and must use loopback.
    final host = !android && emulatorHost == '10.0.2.2'
        ? '127.0.0.1'
        : emulatorHost;
    return hostForPlatform(host: host, android: android);
  }

  static Future<void> connectEmulators({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    if (!useEmulators) return;

    await (auth ?? FirebaseAuth.instance).useAuthEmulator(
      connectionHost,
      authPort,
    );
    (firestore ?? FirebaseFirestore.instance).useFirestoreEmulator(
      connectionHost,
      firestorePort,
    );
  }
}
