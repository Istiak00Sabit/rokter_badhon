import 'auth_link_model.dart';
import 'user_model.dart';

enum AuthSessionState {
  unauthenticated,
  emailUnverified,
  unlinked,
  linkInactive,
  userMissing,
  userInactive,
  loginDisabled,
  invalidRole,
  admitted,
  error,
}

class AuthSessionResult {
  final AuthSessionState state;
  final UserModel? user;
  final Object? error;

  const AuthSessionResult(this.state, {this.user, this.error});

  bool get isAdmitted => state == AuthSessionState.admitted && user != null;
}

class AuthSessionPolicy {
  const AuthSessionPolicy._();

  static AuthSessionState evaluate({
    required bool authenticated,
    required bool emailVerified,
    required bool linkDocumentExists,
    required AuthLinkModel? link,
    required bool userDocumentExists,
    required UserModel? user,
    bool hadError = false,
  }) {
    if (hadError) return AuthSessionState.error;
    if (!authenticated) return AuthSessionState.unauthenticated;
    if (!emailVerified) return AuthSessionState.emailUnverified;
    if (!linkDocumentExists) return AuthSessionState.unlinked;
    if (link == null) return AuthSessionState.error;
    if (!link.active) return AuthSessionState.linkInactive;
    if (!userDocumentExists) return AuthSessionState.userMissing;
    if (user == null) return AuthSessionState.error;
    if (!user.active) return AuthSessionState.userInactive;
    if (!user.loginEnabled) return AuthSessionState.loginDisabled;
    if (!user.hasRecognizedAccessRole) return AuthSessionState.invalidRole;
    return AuthSessionState.admitted;
  }
}

class ProtectedSessionPolicy {
  const ProtectedSessionPolicy._();

  static bool requiresReauthentication({
    required String? previousRole,
    required AuthSessionResult refreshed,
  }) {
    if (!refreshed.isAdmitted) return true;
    return previousRole == null || refreshed.user!.accessRole != previousRole;
  }
}
