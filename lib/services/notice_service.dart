import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notice_model.dart';

class NoticeServiceException implements Exception {
  final String code;
  const NoticeServiceException(this.code);
}

class NoticePage {
  final List<NoticeModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const NoticePage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class NoticeService {
  final FirebaseFirestore _firestore;
  NoticeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  Future<NoticePage> getByStatusPage(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    if (!{'draft', 'published', 'archived'}.contains(status)) {
      throw const NoticeDataException('Unknown requested notice status.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw const NoticeServiceException('invalid_limit');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('notices')
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true);
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      final values = docs
          .map((doc) => NoticeModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (values.any((value) => value.status != status)) {
        throw const NoticeDataException(
          'Notice query returned an unapproved state.',
        );
      }
      return NoticePage(
        items: List<NoticeModel>.unmodifiable(values),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
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

  /// Compatibility callers get only a bounded first page.
  Future<List<NoticeModel>> getByStatus(String status, {int? limit}) async =>
      (await getByStatusPage(status, pageSize: limit ?? 30)).items;

}
