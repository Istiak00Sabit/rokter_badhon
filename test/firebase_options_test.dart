import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/firebase_options.dart';

void main() {
  test(
    'Web Firebase options target the existing project without replacing Android config',
    () {
      expect(DefaultFirebaseOptions.web.projectId, 'rokterbadhon-b247b');
      expect(
        DefaultFirebaseOptions.web.authDomain,
        'rokterbadhon-b247b.firebaseapp.com',
      );
      expect(
        DefaultFirebaseOptions.web.messagingSenderId,
        DefaultFirebaseOptions.android.messagingSenderId,
      );
      expect(DefaultFirebaseOptions.android.appId, contains(':android:'));
      expect(DefaultFirebaseOptions.web.appId, isNotEmpty);
    },
  );

  test('Web no longer throws an unconfigured-platform error', () {
    final source = File('lib/firebase_options.dart').readAsStringSync();
    expect(source, contains('if (kIsWeb) return web;'));
    expect(source, contains('static const FirebaseOptions web'));
    expect(source, isNot(contains('have not been configured for web')));
  });
}
