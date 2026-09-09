import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profile_update.dart';
import '../models/user_directory_model.dart';
import '../models/user_model.dart';

class ProfileUpdateException implements Exception {
  final String message;
  const ProfileUpdateException(this.message);

  @override
  String toString() => message;
}

class UserService {
  static const directoryCollection = 'user_directory';
  static const directoryActiveField = 'active';

  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<UserDirectoryModel>> getActiveDirectory() async {
    final snapshot = await _firestore
        .collection(directoryCollection)
        .where(directoryActiveField, isEqualTo: true)
        .get();
    final entries = snapshot.docs
        .map((doc) => UserDirectoryModel.fromMap(doc.data(), doc.id))
        .toList();
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  Future<void> updateOwnProfile({
    required String userId,
    required ProfileUpdateInput input,
  }) async {
    if (userId.isEmpty || userId.contains('/')) {
      throw const ProfileUpdateException('Invalid linked application User ID.');
    }

    final userReference = _firestore.collection('users').doc(userId);
    final directoryReference = _firestore
        .collection(directoryCollection)
        .doc(userId);
    final documents = await Future.wait([
      userReference.get(),
      directoryReference.get(),
    ]);
    final userData = documents[0].data();
    final directoryData = documents[1].data();
    if (!documents[0].exists || userData == null) {
      throw const ProfileUpdateException('Own User profile is unavailable.');
    }
    if (!documents[1].exists || directoryData == null) {
      throw const ProfileUpdateException(
        'Directory projection is missing; trusted operator repair is required.',
      );
    }

    late final UserModel currentUser;
    late final UserDirectoryModel currentDirectory;
    try {
      currentUser = UserModel.fromMap(userData, userId);
      currentDirectory = UserDirectoryModel.fromMap(directoryData, userId);
    } on FormatException catch (error) {
      throw ProfileUpdateException(
        'Profile or directory data is malformed; trusted operator repair is required: $error',
      );
    }

    validateExistingProjection(currentUser, currentDirectory);

    final requested = input.toMap();
    final currentEditable = {
      'name': currentUser.name,
      'phone': currentUser.phone,
      'blood_group': currentUser.bloodGroup,
      'profession': currentUser.profession,
      'address': currentUser.address,
      'preferred_language': currentUser.preferredLanguage,
    };
    final changed = <String, dynamic>{};
    for (final key in ProfileUpdateInput.editableFields) {
      if (requested[key] != currentEditable[key]) changed[key] = requested[key];
    }
    if (changed.isEmpty) {
      throw const ProfileUpdateException('No profile changes were provided.');
    }

    final userChanges = <String, dynamic>{
      ...changed,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': userId,
    };
    final directoryChanges = <String, dynamic>{
      for (final entry in changed.entries)
        if (ProfileUpdateInput.projectedFields.contains(entry.key))
          entry.key: entry.value,
    };

    final batch = _firestore.batch()..update(userReference, userChanges);
    if (directoryChanges.isNotEmpty) {
      batch.update(directoryReference, directoryChanges);
    }
    await batch.commit();
  }

  static bool _sameMap(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static void validateExistingProjection(
    UserModel user,
    UserDirectoryModel? directory,
  ) {
    if (directory == null) {
      throw const ProfileUpdateException(
        'Directory projection is missing; trusted operator repair is required.',
      );
    }
    final expectedProjection = {
      'name': user.name,
      'phone': user.phone,
      'blood_group': user.bloodGroup,
      'profession': user.profession,
      'photo_url': user.photoUrl,
      'active': user.active,
    };
    if (!_sameMap(directory.toMap(), expectedProjection)) {
      throw const ProfileUpdateException(
        'Directory projection is out of sync; trusted operator repair is required.',
      );
    }
  }
}
