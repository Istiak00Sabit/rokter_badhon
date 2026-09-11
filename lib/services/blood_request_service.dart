import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blood_request_model.dart';

class BloodRequestServiceException implements Exception {
  final String code;
  const BloodRequestServiceException(this.code);
}

class BloodRequestService {
  final FirebaseFirestore _firestore;
  BloodRequestService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<BloodRequestModel>> getByStatus(String status) async {
    if (!{'active', 'fulfilled', 'cancelled'}.contains(status)) {
      throw const BloodRequestDataException('Unknown requested status.');
    }
    try {
      final snapshot = await _firestore
          .collection('blood_requests')
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true)
          .get();
      final values = snapshot.docs
          .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (values.any((value) => value.status != status)) {
        throw const BloodRequestDataException(
          'Request query returned an unapproved state.',
        );
      }
      return values;
    } on BloodRequestDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BloodRequestServiceException(_code(error.code));
    }
  }

  Future<String> create(BloodRequestInput input, String actorId) async {
    try {
      final reference = await _firestore
          .collection('blood_requests')
          .add(input.createMap(actorId));
      return reference.id;
    } on BloodRequestDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BloodRequestServiceException(_code(error.code));
    }
  }

  static String _code(String code) => switch (code) {
    'permission-denied' => 'permission_denied',
    'failed-precondition' => 'query_unavailable',
    'unavailable' || 'network-request-failed' => 'network_unavailable',
    _ => 'operation_failed',
  };
}
