import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notice_model.dart';

class NoticeServiceException implements Exception {
  final String code;
  const NoticeServiceException(this.code);
}

class NoticeService {
  final FirebaseFirestore _firestore;
  NoticeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  Future<List<NoticeModel>> getByStatus(String status, {int? limit}) async {
    if (!{'draft', 'published', 'archived'}.contains(status)) {
      throw const NoticeDataException('Unknown requested notice status.');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('notices')
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true);
      if (limit != null) query = query.limit(limit);
      final snapshot = await query.get();
      final values = snapshot.docs
          .map((doc) => NoticeModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (values.any((value) => value.status != status)) {
        throw const NoticeDataException(
          'Notice query returned an unapproved state.',
        );
      }
      return values;
    } on NoticeDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw NoticeServiceException(switch (error.code) {
        'permission-denied' => 'permission_denied',
        'failed-precondition' => 'query_unavailable',
        'unavailable' || 'network-request-failed' => 'network_unavailable',
        _ => 'operation_failed',
      });
    }
  }
}
