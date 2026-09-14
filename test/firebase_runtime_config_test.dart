import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/config/firebase_runtime_config.dart';

void main() {
  test(
    'local credential adapter is available only in explicit emulator mode',
    () {
      expect(
        FirebaseRuntimeConfig.isLocalTestCredential(
          email: 'a@a.com',
          password: '1',
          emulatorMode: true,
        ),
        isTrue,
      );
      expect(
        FirebaseRuntimeConfig.isLocalTestCredential(
          email: 'a@a.com',
          password: '1',
          emulatorMode: false,
        ),
        isFalse,
      );
      expect(
        FirebaseRuntimeConfig.passwordForAuth(
          email: 'a@a.com',
          password: '1',
          emulatorMode: false,
        ),
        '1',
      );
      expect(
        FirebaseRuntimeConfig.passwordForAuth(
          email: 'a@a.com',
          password: '1',
          emulatorMode: true,
        ),
        '111111',
      );
    },
  );
}
