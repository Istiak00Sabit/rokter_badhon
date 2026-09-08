import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // CURRENT FIREBASE AUTH USER
  // =========================================================

  User? get currentUser =>
      _auth.currentUser;

  // =========================================================
  // LOGIN STATUS
  // =========================================================

  bool get isLoggedIn =>
      _auth.currentUser != null;

  Future<UserModel?> _findProfile(String authUid) async {
    final users = _firestore.collection(AppConstants.usersCollection);

    // Phase 1 compatibility: keep the existing developer admin document path.
    // No fields are written or inferred for organization-only users.
    final existing = await users.doc(authUid).get();
    final data = existing.data();
    if (data != null) {
      final profile = UserModel.fromMap(data, existing.id);
      if (profile.authUid == authUid) return profile;
      if (profile.role == AppConstants.roleAdmin &&
          !data.containsKey('auth_uid') &&
          !data.containsKey('login_enabled')) {
        return profile.copyWith(authUid: authUid, loginEnabled: true);
      }
    }

    // New-schema identities can use any application document ID.
    final matches = await users.where('auth_uid', isEqualTo: authUid).limit(2).get();
    if (matches.docs.length != 1) return null;
    final doc = matches.docs.single;
    return UserModel.fromMap(doc.data(), doc.id);
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth
              .signInWithEmailAndPassword(
        email:
            email.trim(),

        password:
            password.trim(),
      );

      final User? firebaseUser =
          credential.user;

      if (firebaseUser == null) {
        return {
          'success':
              false,

          'message':
              'লগইন করা যায়নি!',
        };
      }

      final profile = await _findProfile(firebaseUser.uid);

      if (profile == null) {
        // Auth হয়েছে কিন্তু application profile নেই।
        await _auth.signOut();

        return {
          'success':
              false,

          'message':
              'ব্যবহারকারীর প্রোফাইল পাওয়া যায়নি!',
        };
      }

      // Account active check
      if (!profile.active || !profile.loginEnabled) {
        await _auth.signOut();

        return {
          'success':
              false,

          'message':
              'আপনার অ্যাকাউন্ট নিষ্ক্রিয় করা হয়েছে!',
        };
      }

      return {
        'success':
            true,

        'message':
            'সফলভাবে লগইন হয়েছে!',

        'role':
            profile.role,
      };
    }

    // Firebase Auth related error
    on FirebaseAuthException catch (e) {
      return {
        'success':
            false,

        'message':
            _getErrorMessage(
          e.code,
        ),
      };
    }

    // Firestore permission / network etc.
    on FirebaseException catch (e) {
      await _auth.signOut();
      print(
        'FIREBASE LOGIN ERROR: ${e.code} - ${e.message}',
      );

      return {
        'success':
            false,

        'message':
            'Firebase সমস্যা: ${e.message ?? e.code}',
      };
    }

    catch (e,stackTrace) {
      await _auth.signOut();
      print(
        'LOGIN ERROR: $e',
      );

      print(
        'LOGIN STACK TRACE: $stackTrace',
      );

      return {
        'success':
            false,

        'message':
            'কিছু একটা ভুল হয়েছে! আবার চেষ্টা করুন।',
      };
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    await _auth.signOut();
  }

  // =========================================================
  // GET CURRENT USER DATA
  // =========================================================

  Future<UserModel?>
      getCurrentUserData() async {
    try {
      final User? user =
          currentUser;

      if (user == null) {
        return null;
      }

      final profile = await _findProfile(user.uid);
      if (profile == null || !profile.active || !profile.loginEnabled) {
        return null;
      }
      return profile;
    } on FirebaseException catch (e) {
      print(
        'GET CURRENT USER FIREBASE ERROR: ${e.code} - ${e.message}',
      );

      return null;
    } catch (e) {
      print(
        'GET CURRENT USER ERROR: $e',
      );

      return null;
    }
  }

  // =========================================================
  // AUTH ERROR MESSAGE
  // =========================================================

  String _getErrorMessage(
    String code,
  ) {
    switch (code) {
      case 'user-not-found':
        return 'এই ইমেইলে কোনো অ্যাকাউন্ট নেই!';

      case 'wrong-password':
        return 'পাসওয়ার্ড ভুল হয়েছে!';

      case 'invalid-email':
        return 'ইমেইল ঠিকানা সঠিক নয়!';

      case 'user-disabled':
        return 'এই অ্যাকাউন্ট বন্ধ করা হয়েছে!';

      case 'too-many-requests':
        return 'অনেকবার চেষ্টা করা হয়েছে! কিছুক্ষণ পর আবার চেষ্টা করুন।';

      case 'invalid-credential':
        return 'ইমেইল বা পাসওয়ার্ড ভুল হয়েছে!';

      case 'network-request-failed':
        return 'ইন্টারনেট সংযোগ পরীক্ষা করুন!';

      default:
        return 'লগইন করতে সমস্যা হয়েছে! আবার চেষ্টা করুন।';
    }
  }
}
