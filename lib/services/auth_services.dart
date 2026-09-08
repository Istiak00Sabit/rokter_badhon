import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_link_model.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';

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
