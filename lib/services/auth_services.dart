import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_link_model.dart';
import '../models/auth_session.dart';
import '../models/registration_request_model.dart';
import '../models/user_model.dart';

enum RegistrationSubmissionState {
  submitted,
  submittedVerificationEmailFailed,
  submittedSignOutFailed,
  authCreatedRequestFailed,
  failed,
}

class RegistrationSubmissionResult {
  final RegistrationSubmissionState state;
  final Object? error;
  final bool emailVerificationSent;

  const RegistrationSubmissionResult(
    this.state, {
    this.error,
    this.emailVerificationSent = false,
  });

  bool get requestSubmitted =>
      state == RegistrationSubmissionState.submitted ||
      state == RegistrationSubmissionState.submittedVerificationEmailFailed ||
      state == RegistrationSubmissionState.submittedSignOutFailed;
  bool get authAccountCreated => state != RegistrationSubmissionState.failed;
}

class RegistrationIdentity {
  final String uid;
  final String email;

  const RegistrationIdentity({required this.uid, required this.email});
}

class RegistrationWorkflow {
  const RegistrationWorkflow._();

  static Future<RegistrationSubmissionResult> createAndSubmit({
    required RegistrationApplicantInput applicant,
    required Future<RegistrationIdentity> Function() createIdentity,
    required Future<void> Function(RegistrationIdentity identity)
    sendVerification,
    required Future<void> Function(
      RegistrationIdentity identity,
      Map<String, dynamic> payload,
    )
    writeRequest,
    required Future<void> Function() signOut,
  }) async {
    late final RegistrationIdentity identity;
    try {
      identity = await createIdentity();
    } catch (error) {
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.failed,
        error: error,
      );
    }

    var verificationSent = false;
    try {
      await sendVerification(identity);
      verificationSent = true;
    } catch (_) {
      // Request submission remains recoverable when email delivery fails.
    }

    return submitExisting(
      identity: identity,
      applicant: RegistrationApplicantInput(
        name: applicant.name,
        phone: applicant.phone,
        // Firebase Auth's returned email is authoritative for Rules binding.
        email: identity.email,
      ),
      writeRequest: writeRequest,
      signOut: signOut,
      emailVerificationSent: verificationSent,
    );
  }

  static Future<RegistrationSubmissionResult> submitExisting({
    required RegistrationIdentity identity,
    required RegistrationApplicantInput applicant,
    required Future<void> Function(
      RegistrationIdentity identity,
      Map<String, dynamic> payload,
    )
    writeRequest,
    required Future<void> Function() signOut,
    bool emailVerificationSent = true,
  }) async {
    try {
      final payload = RegistrationRequestPayload.create(
        authUid: identity.uid,
        authenticatedEmail: identity.email,
        applicant: applicant,
      );
      await writeRequest(identity, payload);
    } catch (error) {
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.authCreatedRequestFailed,
        error: error,
        emailVerificationSent: emailVerificationSent,
      );
    }

    try {
      await signOut();
    } catch (error) {
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.submittedSignOutFailed,
        error: error,
        emailVerificationSent: emailVerificationSent,
      );
    }

    return RegistrationSubmissionResult(
      emailVerificationSent
          ? RegistrationSubmissionState.submitted
          : RegistrationSubmissionState.submittedVerificationEmailFailed,
      emailVerificationSent: emailVerificationSent,
    );
  }
}

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        // Passwords are passed to Firebase exactly as entered.
        password: password,
      );
      return resolveSession(firebaseUser: credential.user);
    } on FirebaseAuthException catch (error) {
      return AuthSessionResult(AuthSessionState.error, error: error);
    } catch (error) {
      return AuthSessionResult(AuthSessionState.error, error: error);
    }
  }

  Future<AuthSessionResult> resolveSession({User? firebaseUser}) async {
    final initialUser = firebaseUser ?? _auth.currentUser;
    if (initialUser == null) {
      return const AuthSessionResult(AuthSessionState.unauthenticated);
    }

    try {
      await initialUser.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        return const AuthSessionResult(AuthSessionState.unauthenticated);
      }
      if (!refreshedUser.emailVerified) {
        return const AuthSessionResult(AuthSessionState.emailUnverified);
      }

      final linkDocument = await _firestore
          .collection('auth_links')
          .doc(refreshedUser.uid)
          .get();
      final linkData = linkDocument.data();
      if (!linkDocument.exists || linkData == null) {
        return const AuthSessionResult(AuthSessionState.unlinked);
      }

      final link = AuthLinkModel.fromMap(linkData, refreshedUser.uid);
      if (!link.active) {
        return const AuthSessionResult(AuthSessionState.linkInactive);
      }

      final userDocument = await _firestore
          .collection('users')
          .doc(link.userId)
          .get();
      final userData = userDocument.data();
      if (!userDocument.exists || userData == null) {
        return const AuthSessionResult(AuthSessionState.userMissing);
      }

      final user = UserModel.fromMap(userData, userDocument.id);
      final state = AuthSessionPolicy.evaluate(
        authenticated: true,
        emailVerified: true,
        linkDocumentExists: true,
        link: link,
        userDocumentExists: true,
        user: user,
      );
      return AuthSessionResult(
        state,
        user: state == AuthSessionState.admitted ? user : null,
      );
    } on FirebaseException catch (error) {
      // Permission and network failures are operational errors, never a
      // fabricated missing-User result.
      return AuthSessionResult(AuthSessionState.error, error: error);
    } on FormatException catch (error) {
      return AuthSessionResult(AuthSessionState.error, error: error);
    } catch (error) {
      return AuthSessionResult(AuthSessionState.error, error: error);
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    final result = await resolveSession();
    return result.isAdmitted ? result.user : null;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<RegistrationSubmissionResult> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    User? createdUser;
    return RegistrationWorkflow.createAndSubmit(
      applicant: RegistrationApplicantInput(
        name: name.trim(),
        phone: phone.trim(),
        email: email.trim(),
      ),
      createIdentity: () async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        createdUser = credential.user;
        final authenticatedEmail = createdUser?.email;
        if (createdUser == null || authenticatedEmail == null) {
          throw StateError('Firebase Auth did not return an account identity.');
        }
        return RegistrationIdentity(
          uid: createdUser!.uid,
          email: authenticatedEmail,
        );
      },
      sendVerification: (_) => createdUser!.sendEmailVerification(),
      writeRequest: (identity, payload) => _firestore
          .collection('registration_requests')
          .doc(identity.uid)
          .set(payload),
      signOut: _auth.signOut,
    );
  }

  Future<RegistrationRequestModel?> getOwnRegistrationRequest() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    final document = await _firestore
        .collection('registration_requests')
        .doc(user.uid)
        .get();
    final data = document.data();
    if (!document.exists || data == null) return null;
    return RegistrationRequestModel.fromMap(data, document.id);
  }

  Future<RegistrationSubmissionResult> submitOwnRegistrationRequest({
    required String name,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('An authenticated account with email is required.');
    }
    return RegistrationWorkflow.submitExisting(
      identity: RegistrationIdentity(uid: user.uid, email: email),
      applicant: RegistrationApplicantInput(
        name: name.trim(),
        phone: phone.trim(),
        email: email,
      ),
      writeRequest: (identity, payload) => _firestore
          .collection('registration_requests')
          .doc(identity.uid)
          .set(payload),
      signOut: _auth.signOut,
    );
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    await user.sendEmailVerification();
  }

  Future<void> logout() => _auth.signOut();

  String authErrorCode(Object? error) {
    if (error is! FirebaseAuthException) {
      return 'auth_check_failed';
    }
    switch (error.code) {
      case 'user-not-found':
        return 'auth_user_not_found';
      case 'wrong-password':
      case 'invalid-credential':
        return 'auth_invalid_credential';
      case 'invalid-email':
        return 'auth_invalid_email';
      case 'user-disabled':
        return 'auth_user_disabled';
      case 'too-many-requests':
        return 'auth_too_many_requests';
      case 'network-request-failed':
        return 'network_unavailable';
      default:
        return 'login_failed';
    }
  }
}
