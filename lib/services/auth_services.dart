import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_link_model.dart';
import '../models/auth_session.dart';
import '../models/registration_request_model.dart';
import '../models/user_model.dart';
import 'auth_identity.dart';

/// A previously created Firebase identity requires operator-led migration.
/// No client-side account replacement, password reset, or identity relinking.
class RegistrationIdentityReviewRequired implements Exception {
  const RegistrationIdentityReviewRequired();
}

enum RegistrationSubmissionState {
  submitted,
  @Deprecated('Email verification is not part of admission.')
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
  final String authEmail;

  const RegistrationIdentity({
    required this.uid,
    required this.authEmail,
  });

  String get email => authEmail;
}

class RegistrationWorkflow {
  const RegistrationWorkflow._();

  static Future<RegistrationSubmissionResult> createAndSubmit({
    required RegistrationApplicantInput applicant,
    required Future<RegistrationIdentity> Function() createIdentity,
    Future<void> Function(RegistrationIdentity identity)? sendVerification,
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

    final normalizedPhone = AuthIdentity.normalizePhone(applicant.phone);
    final expectedIdentity = AuthIdentity.internalEmailForPhone(normalizedPhone);
    if (identity.authEmail.trim().toLowerCase() != expectedIdentity) {
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.failed,
        error: const FormatException(
          'Firebase Auth identity does not match the registration phone.',
        ),
      );
    }

    return submitExisting(
      identity: identity,
      applicant: RegistrationApplicantInput(
        name: applicant.name,
        phone: normalizedPhone,
        email: applicant.email,
        bloodGroup: applicant.bloodGroup,
        profession: applicant.profession,
        address: applicant.address,
        union: applicant.union,
        village: applicant.village,
      ),
      writeRequest: writeRequest,
      signOut: signOut,
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
  }) async {
    try {
      final normalizedPhone = AuthIdentity.normalizePhone(applicant.phone);
      final expectedIdentity = AuthIdentity.internalEmailForPhone(normalizedPhone);
      if (identity.authEmail.trim().toLowerCase() != expectedIdentity) {
        throw const FormatException(
          'Firebase Auth identity does not match the registration phone.',
        );
      }
      final applicantEmail = applicant.email?.trim().toLowerCase();
      final payload = RegistrationRequestPayload.create(
        authUid: identity.uid,
        applicant: RegistrationApplicantInput(
          name: applicant.name,
          phone: normalizedPhone,
          email: applicantEmail,
          bloodGroup: applicant.bloodGroup,
          profession: applicant.profession,
          address: applicant.address,
          union: applicant.union,
          village: applicant.village,
        ),
      );
      await writeRequest(identity, payload);
    } catch (error) {
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.authCreatedRequestFailed,
        error: error,
      );
    }

    try {
      await signOut();
    } catch (error) {
      return RegistrationSubmissionResult(
        RegistrationSubmissionState.submittedSignOutFailed,
        error: error,
      );
    }

    return RegistrationSubmissionResult(
      RegistrationSubmissionState.submitted,
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
    required String phone,
    required String password,
  }) async {
    try {
      final identifier = phone.trim();
      final authEmail = identifier.contains('@')
          ? identifier
          : AuthIdentity.internalEmailForPhone(identifier);
      final credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      return await resolveSession(firebaseUser: credential.user);
    } on FirebaseAuthException catch (error) {
      _logAuthFailure('sign-in', error);
      return AuthSessionResult(AuthSessionState.error, error: error);
    } catch (error) {
      _logAuthFailure('sign-in', error);
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
      final linkDocument = await _firestore
          .collection('auth_links')
          .doc(refreshedUser.uid)
          .get();
      final linkData = linkDocument.data();
      if (!linkDocument.exists || linkData == null) {
        // The requester can read their own request only while unlinked.
        // Distinguish pending/rejected applications from absent requests,
        // without treating any request as a login authorization.
        final requestDocument = await _firestore
            .collection('registration_requests')
            .doc(refreshedUser.uid)
            .get();
        if (!requestDocument.exists || requestDocument.data() == null) {
          return const AuthSessionResult(AuthSessionState.unlinked);
        }
        final request = RegistrationRequestModel.fromMap(
          requestDocument.data()!,
          requestDocument.id,
        );
        return AuthSessionResult(UnlinkedRegistrationPolicy.evaluate(request));
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
      _logAuthFailure('session-check', error);
      return AuthSessionResult(AuthSessionState.error, error: error);
    } on FormatException catch (error) {
      _logAuthFailure('session-parse', error);
      return AuthSessionResult(AuthSessionState.error, error: error);
    } catch (error) {
      _logAuthFailure('session-check', error);
      return AuthSessionResult(AuthSessionState.error, error: error);
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    final result = await resolveSession();
    return result.isAdmitted ? result.user : null;
  }

  Future<RegistrationSubmissionResult> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? bloodGroup,
    String? profession,
    String? address,
    String? union,
    String? village,
  }) async {
    final normalizedPhone = AuthIdentity.normalizePhone(phone);
    final profileEmail = _nullableTrim(email)?.toLowerCase();
    if (profileEmail != null &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(profileEmail)) {
      return const RegistrationSubmissionResult(
        RegistrationSubmissionState.failed,
        error: FormatException('Enter a valid profile email.'),
      );
    }
    // Both account creation and phone login use the same private identifier.
    final authEmail = AuthIdentity.internalEmailForPhone(normalizedPhone);
    return RegistrationWorkflow.createAndSubmit(
      applicant: RegistrationApplicantInput(
        name: name.trim(),
        phone: normalizedPhone,
        email: profileEmail,
        bloodGroup: _nullableTrim(bloodGroup),
        profession: _nullableTrim(profession),
        address: _nullableTrim(address),
        union: _nullableTrim(union),
        village: _nullableTrim(village),
      ),
      createIdentity: () async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        final createdUser = credential.user;
        if (createdUser == null ||
            createdUser.email?.toLowerCase() != authEmail) {
          throw StateError(
            'Firebase Auth did not return the requested phone identity.',
          );
        }
        return RegistrationIdentity(
          uid: createdUser.uid,
          authEmail: authEmail,
        );
      },
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
    String? email,
    String? bloodGroup,
    String? profession,
    String? address,
    String? union,
    String? village,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('An authenticated Firebase account is required.');
    }
    final normalizedPhone = AuthIdentity.normalizePhone(phone);
    final expectedIdentity = AuthIdentity.internalEmailForPhone(normalizedPhone);
    if (user.email?.toLowerCase() != expectedIdentity) {
      throw const RegistrationIdentityReviewRequired();
    }
    final profileEmail = _nullableTrim(email)?.toLowerCase();
    if (profileEmail != null &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(profileEmail)) {
      throw const FormatException('Enter a valid profile email.');
    }
    return RegistrationWorkflow.submitExisting(
      identity: RegistrationIdentity(
        uid: user.uid,
        authEmail: expectedIdentity,
      ),
      applicant: RegistrationApplicantInput(
        name: name.trim(),
        phone: normalizedPhone,
        email: profileEmail,
        bloodGroup: _nullableTrim(bloodGroup),
        profession: _nullableTrim(profession),
        address: _nullableTrim(address),
        union: _nullableTrim(union),
        village: _nullableTrim(village),
      ),
      writeRequest: (identity, payload) => _firestore
          .collection('registration_requests')
          .doc(identity.uid)
          .set(payload),
      signOut: _auth.signOut,
    );
  }

  Future<void> logout() => _auth.signOut();

  String authErrorCode(Object? error) {
    return mapAuthErrorCode(error);
  }

  static String mapRegistrationSubmissionError(Object? error) {
    if (error is RegistrationIdentityReviewRequired) {
      return 'registration_identity_review_required';
    }
    final code = switch (error) {
      FirebaseAuthException authError => authError.code,
      FirebaseException firebaseError => firebaseError.code,
      _ => null,
    };
    return switch (code) {
      'email-already-in-use' => 'registration_already_registered',
      'invalid-email' => 'auth_invalid_email',
      'weak-password' => 'password_min_length',
      'operation-not-allowed' => 'auth_operation_not_allowed',
      'too-many-requests' => 'auth_too_many_requests',
      'permission-denied' => 'registration_permission_denied',
      'failed-precondition' => 'registration_query_unavailable',
      'unavailable' || 'network-request-failed' => 'registration_network_failed',
      _ => error is FormatException
          ? 'registration_invalid'
          : 'registration_request_failed',
    };
  }

  static String mapAuthErrorCode(Object? error) {
    final code = switch (error) {
      FirebaseAuthException authError => authError.code,
      FirebaseException firebaseError => firebaseError.code,
      _ => null,
    };
    if (code == null) return 'auth_check_failed';
    switch (code) {
      case 'user-not-found':
      case 'invalid-password':
      case 'wrong-password':
      case 'invalid-credential':
        // Avoid revealing whether an email exists while still reporting a
        // credential/login failure rather than a connectivity problem.
        return 'auth_invalid_credential';
      case 'invalid-email':
        return 'auth_invalid_email';
      case 'user-disabled':
        return 'auth_user_disabled';
      case 'too-many-requests':
        return 'auth_too_many_requests';
      case 'network-request-failed':
      case 'unavailable':
        return 'network_unavailable';
      default:
        return error is FirebaseAuthException
            ? 'login_failed'
            : 'auth_check_failed';
    }
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _logAuthFailure(String stage, Object error) {
    if (!kDebugMode) return;
    final code = switch (error) {
      FirebaseAuthException authError => authError.code,
      FirebaseException firebaseError => firebaseError.code,
      _ => null,
    };
    // Codes are useful for local diagnosis; passwords, emails, tokens and
    // backend exception messages are intentionally excluded.
    debugPrint('Auth $stage failed${code == null ? '' : ' code=$code'}');
  }
}
