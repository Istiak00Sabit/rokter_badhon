import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/donor_model.dart';

class DonorServiceException implements Exception {
  final String code;
  const DonorServiceException(this.code);
}

class DonorService {
  final FirebaseFirestore _firestore;

  DonorService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> addDonor({
    required DonorInput input,
    required String actorUserId,
  }) async {
    _validateId(actorUserId, 'actor');
    final reference = _firestore
        .collection(AppConstants.donorsCollection)
        .doc();
    final timestamp = FieldValue.serverTimestamp();
    try {
      await reference.set({
        ...input.profileFields(),
        'linked_user_id': null,
        'active': true,
        'last_donated_at': null,
        'total_donations': 0,
        'created_at': timestamp,
        'created_by': actorUserId,
        'updated_at': timestamp,
        'updated_by': actorUserId,
      });
      return reference.id;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  Future<void> editDonor({
    required String donorId,
    required DonorInput input,
    required String actorUserId,
  }) async {
    _validateId(donorId, 'donor');
    _validateId(actorUserId, 'actor');
    try {
      await _firestore
          .collection(AppConstants.donorsCollection)
          .doc(donorId)
          .update({
            ...input.profileFields(),
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': actorUserId,
          });
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  Future<List<DonorModel>> getAllDonors() => _queryActiveDonors();

  Future<List<DonorModel>> getDonorsByBloodGroup(String bloodGroup) {
    if (bloodGroup.trim().isEmpty) {
      throw const DonorDataException('blood_group is required.');
    }
    return _queryActiveDonors(bloodGroup: bloodGroup);
  }

  Future<List<DonorModel>> _queryActiveDonors({String? bloodGroup}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.donorsCollection)
        .where('active', isEqualTo: true);
    if (bloodGroup != null) {
      query = query.where('blood_group', isEqualTo: bloodGroup);
    }
    try {
      final snapshot = bloodGroup == null
          ? await query.orderBy('name').get()
          : await query.get();
      final donors = snapshot.docs
          .map((doc) => DonorModel.fromMap(doc.data(), doc.id))
          .toList();
      if (bloodGroup != null) {
        donors.sort((left, right) => left.name.compareTo(right.name));
      }
      return List.unmodifiable(donors);
    } on DonorDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  static String _safeCode(String code) => switch (code) {
    'permission-denied' => 'permission_denied',
    'failed-precondition' => 'query_unavailable',
    'unavailable' || 'network-request-failed' => 'network_unavailable',
    _ => 'operation_failed',
  };

  static void _validateId(String value, String label) {
    if (value.isEmpty || value.contains('/')) {
      throw DonorDataException('Invalid $label document ID.');
    }
  }
}
