import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/auth_link_model.dart';
import 'package:rokter_badhon/models/auth_session.dart';
import 'package:rokter_badhon/models/user_model.dart';

void main() {
  final time = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
  AuthLinkModel link({bool active = true}) => AuthLinkModel.fromMap({
    'user_id': 'user-id',
    'active': active,
    'created_at': time,
    'created_by': 'creator-id',
  }, 'auth-uid');
  UserModel user({
    bool active = true,
    bool loginEnabled = true,
    String accessRole = 'member',
  }) => UserModel.fromMap({
    'name': 'Synthetic User',
    'phone': '00000000000',
    'email': null,
    'blood_group': null,
    'profession': null,
    'address': null,
    'photo_url': null,
    'access_role': accessRole,
    'active': active,
    'login_enabled': loginEnabled,
    'preferred_language': null,
    'created_at': time,
    'created_by': null,
    'updated_at': time,
    'updated_by': null,
  }, 'user-id');

  AuthSessionState evaluate({
    bool authenticated = true,
    bool emailVerified = true,
    bool linkExists = true,
    AuthLinkModel? authLink,
    bool userExists = true,
    UserModel? profile,
    bool hadError = false,
  }) => AuthSessionPolicy.evaluate(
    authenticated: authenticated,
    emailVerified: emailVerified,
    linkDocumentExists: linkExists,
    link: authLink ?? link(),
    userDocumentExists: userExists,
    user: profile ?? user(),
    hadError: hadError,
  );

  test('session policy maps every explicit admission state', () {
    expect(evaluate(authenticated: false), AuthSessionState.unauthenticated);
    expect(evaluate(emailVerified: false), AuthSessionState.emailUnverified);
    expect(evaluate(linkExists: false), AuthSessionState.unlinked);
    expect(
      evaluate(authLink: link(active: false)),
      AuthSessionState.linkInactive,
    );
    expect(evaluate(userExists: false), AuthSessionState.userMissing);
    expect(
      evaluate(profile: user(active: false)),
      AuthSessionState.userInactive,
    );
    expect(
      evaluate(profile: user(loginEnabled: false)),
      AuthSessionState.loginDisabled,
    );
    expect(
      evaluate(profile: user(accessRole: 'admin')),
      AuthSessionState.invalidRole,
    );
    expect(evaluate(), AuthSessionState.admitted);
    expect(evaluate(hadError: true), AuthSessionState.error);
  });

  test('malformed loaded models map to error rather than missing records', () {
    expect(
      AuthSessionPolicy.evaluate(
        authenticated: true,
        emailVerified: true,
        linkDocumentExists: true,
        link: null,
        userDocumentExists: false,
        user: null,
      ),
      AuthSessionState.error,
    );
    expect(
      AuthSessionPolicy.evaluate(
        authenticated: true,
        emailVerified: true,
        linkDocumentExists: true,
        link: link(),
        userDocumentExists: true,
        user: null,
      ),
      AuthSessionState.error,
    );
  });
}
