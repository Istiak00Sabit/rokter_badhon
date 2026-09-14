import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseRuntimeConfig {
  static const String _localTestAdminEmail = 'a@a.com';
  static const String _localTestPassword = '1';
  static const String _firebaseCompatibleTestPassword = '111111';
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

  static bool isLocalTestCredential({
    required String email,
    required String password,
    bool emulatorMode = useEmulators,
  }) =>
      emulatorMode &&
      email.trim().toLowerCase() == _localTestAdminEmail &&
      password == _localTestPassword;

  static String passwordForAuth({
    required String email,
    required String password,
    bool emulatorMode = useEmulators,
  }) =>
      isLocalTestCredential(
        email: email,
        password: password,
        emulatorMode: emulatorMode,
      )
      ? _firebaseCompatibleTestPassword
      : password;

  static Future<void> connectEmulators({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    if (!useEmulators) return;

    await (auth ?? FirebaseAuth.instance).useAuthEmulator(
      emulatorHost,
      authPort,
    );
    (firestore ?? FirebaseFirestore.instance).useFirestoreEmulator(
      emulatorHost,
      firestorePort,
    );
  }
}
