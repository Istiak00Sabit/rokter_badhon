import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_link_model.dart';
import '../models/auth_session.dart';
import '../models/registration_request_model.dart';
import '../models/user_model.dart';

enum RegistrationSubmissionState {
  submitted,
  submittedVerificationEmailFailed,
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
      state == RegistrationSubmissionState.submittedVerificationEmailFailed;
  bool get authAccountCreated => state != RegistrationSubmissionState.failed;
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
    var verificationSent = false;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = credential.user;
      final authenticatedEmail = createdUser?.email;
      if (createdUser == null || authenticatedEmail == null) {
        throw StateError('Firebase Auth did not return an account identity.');
      }

      try {
        await createdUser.sendEmailVerification();
        verificationSent = true;
      } catch (_) {
        // The request is still submitted below. Resend remains available.
      }

      final applicant = RegistrationApplicantInput(
        name: name.trim(),
        phone: phone.trim(),
        email: authenticatedEmail,
      );
      final payload = RegistrationRequestPayload.create(
        authUid: createdUser.uid,
        authenticatedEmail: authenticatedEmail,
        applicant: applicant,
      );
      await _firestore
          .collection('registration_requests')
          .doc(createdUser.uid)
          .set(payload);

      return RegistrationSubmissionResult(
        verificationSent
            ? RegistrationSubmissionState.submitted
            : RegistrationSubmissionState.submittedVerificationEmailFailed,
        emailVerificationSent: verificationSent,
      );
    } catch (error) {
      if (createdUser != null) {
        return RegistrationSubmissionResult(
          RegistrationSubmissionState.authCreatedRequestFailed,
          error: error,
          emailVerificationSent: verificationSent,
        );
      }
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.failed,
        error: error,
      );
    }
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

  Future<void> submitOwnRegistrationRequest({
    required String name,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('An authenticated account with email is required.');
    }
    final payload = RegistrationRequestPayload.create(
      authUid: user.uid,
      authenticatedEmail: email,
      applicant: RegistrationApplicantInput(
        name: name.trim(),
        phone: phone.trim(),
        email: email,
      ),
    );
    await _firestore
        .collection('registration_requests')
        .doc(user.uid)
        .set(payload);
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

  String authErrorMessage(Object? error) {
    if (error is! FirebaseAuthException) {
      return 'লগইন অনুমতি যাচাই করা যায়নি! আবার চেষ্টা করুন।';
    }
    switch (error.code) {
      case 'user-not-found':
        return 'এই ইমেইলে কোনো অ্যাকাউন্ট নেই!';
      case 'wrong-password':
      case 'invalid-credential':
        return 'ইমেইল বা পাসওয়ার্ড ভুল হয়েছে!';
      case 'invalid-email':
        return 'ইমেইল ঠিকানা সঠিক নয়!';
      case 'user-disabled':
        return 'এই অ্যাকাউন্ট বন্ধ করা হয়েছে!';
      case 'too-many-requests':
        return 'অনেকবার চেষ্টা করা হয়েছে! কিছুক্ষণ পর আবার চেষ্টা করুন।';
      case 'network-request-failed':
        return 'ইন্টারনেট সংযোগ পরীক্ষা করুন!';
      default:
        return 'লগইন করতে সমস্যা হয়েছে! আবার চেষ্টা করুন।';
    }
  }
}
