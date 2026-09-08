import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // ADD ORGANIZATION USER / MEMBER
  // =========================================================

  Future<Map<String, dynamic>> addUser(UserModel user) async {
    try {
      // Firestore নিজে unique document ID তৈরি করবে।
      final DocumentReference<Map<String, dynamic>> docRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc();

      // This operation creates an organization record only, never Auth access.
      final UserModel userToSave = user.copyWith(
        id: docRef.id,
        loginEnabled: false,
      );

      await docRef.set(userToSave.toMap());

      return {
        'success': true,
        'message': 'সদস্য সফলভাবে যোগ করা হয়েছে!',
        'id': docRef.id,
      };
    } on FirebaseException catch (e) {
      return {
        'success': false,
        'message': 'Firebase সমস্যা: ${e.message ?? e.code}',
      };
    } catch (e) {
      return {'success': false, 'message': 'সদস্য যোগ করতে সমস্যা হয়েছে: $e'};
    }
  }

  // =========================================================
  // GET ALL ORGANIZATION USERS
  // =========================================================

  Future<List<UserModel>> getOrganizationUsers() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('active', isEqualTo: true)
          .get();

      final List<UserModel> users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          // Developer Admin member list-এ দেখানো হবে না।
          .where((user) => user.role != AppConstants.roleAdmin)
          .toList();

      // Firestore orderBy ব্যবহার না করে locally sort করছি।
      // এতে unnecessary composite index লাগবে না।
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return users;
    } catch (e) {
      rethrow;
    }
  }

  // =========================================================
  // GET USERS BY COMMITTEE YEAR
  // =========================================================

  Future<List<UserModel>> getUsersByCommitteeYear(int year) async {
    try {
      final List<UserModel> allUsers = await getOrganizationUsers();

      return allUsers.where((user) => user.committeeYear == year).toList();
    } catch (e) {
      rethrow;
    }
  }

  // =========================================================
  // GET SINGLE USER
  // =========================================================

  Future<UserModel?> getUserById(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      rethrow;
    }
  }
}
