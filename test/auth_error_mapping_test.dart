import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/auth_session.dart';
import 'package:rokter_badhon/services/auth_services.dart';

void main() {
  FirebaseAuthException authError(String code) =>
      FirebaseAuthException(code: code);

  test('Firebase Auth errors map to safe, specific user messages', () {
    expect(
      AuthService.mapAuthErrorCode(authError('network-request-failed')),
      'network_unavailable',
    );
    expect(
      AuthService.mapAuthErrorCode(authError('wrong-password')),
      'auth_invalid_credential',
    );
    expect(
      AuthService.mapAuthErrorCode(authError('user-not-found')),
      'auth_invalid_credential',
    );
    expect(
      AuthService.mapAuthErrorCode(authError('user-disabled')),
      'auth_user_disabled',
    );
    expect(
      AuthService.mapAuthErrorCode(authError('unknown-auth-code')),
      'login_failed',
    );
  });

  test(
    'Firestore connectivity is distinguishable from permission/unknown errors',
    () {
      expect(
        AuthService.mapAuthErrorCode(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        'network_unavailable',
      );
      expect(
        AuthService.mapAuthErrorCode(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        'auth_check_failed',
      );
      expect(
        AuthService.mapAuthErrorCode(StateError('unexpected')),
        'auth_check_failed',
      );
    },
  );

  test('admission states are not collapsed into a network error', () {
    expect(
      AuthSessionPolicy.evaluate(
        authenticated: true,
        emailVerified: true,
        linkDocumentExists: false,
        link: null,
        userDocumentExists: false,
        user: null,
      ),
      AuthSessionState.unlinked,
    );
    expect(
      AuthSessionPolicy.evaluate(
        authenticated: true,
        emailVerified: false,
        linkDocumentExists: true,
        link: null,
        userDocumentExists: false,
        user: null,
      ),
      AuthSessionState.error,
    );
  });

  test('the resolver has explicit auth-link and admission branches', () {
    final source = File('lib/services/auth_services.dart').readAsStringSync();
    expect(source, contains("collection('auth_links')"));
    expect(source, contains('AuthSessionState.unlinked'));
    expect(source, contains('AuthSessionState.linkInactive'));
    expect(source, contains('AuthSessionState.userMissing'));
    expect(
      source,
      isNot(
        contains(
          "case 'user-not-found':\n        return 'network_unavailable'",
        ),
      ),
    );
  });
}
