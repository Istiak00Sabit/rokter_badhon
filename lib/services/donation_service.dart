import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/donation_model.dart';

class DonationServiceException implements Exception {
  final String code;
  const DonationServiceException(this.code);
}

class DonationService {
  final FirebaseFirestore _firestore;
  DonationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<DonationModel>> getHistory() async {
    try {
      final snapshot = await _firestore
          .collection('donations')
          .orderBy('donation_date', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
    } on DonationDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonationServiceException(switch (error.code) {
        'permission-denied' => 'permission_denied',
        'unavailable' || 'network-request-failed' => 'network_unavailable',
        _ => 'operation_failed',
      });
    }
  }
}
