import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blood_request_model.dart';

class BloodRequestServiceException implements Exception {
  final String code;
  const BloodRequestServiceException(this.code);
}

/// A bounded page with a snapshot cursor. The extra lookahead document
/// determines if the next page exists without skipping that document.
class BloodRequestPage {
  final List<BloodRequestModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const BloodRequestPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class BloodRequestService {
  final FirebaseFirestore _firestore;
  BloodRequestService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<BloodRequestPage> getByStatusPage(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    if (!{'active', 'fulfilled', 'cancelled'}.contains(status)) {
      throw const BloodRequestDataException('Unknown requested status.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw const BloodRequestServiceException('invalid_limit');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('blood_requests')
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true);
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      final values = docs
          .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (values.any((value) => value.status != status)) {
        throw const BloodRequestDataException(
          'Request query returned an unapproved state.',
        );
      }
      return BloodRequestPage(
        items: List<BloodRequestModel>.unmodifiable(values),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on BloodRequestDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw BloodRequestServiceException(_code(error.code));
    }
  }

  /// Legacy callers receive a bounded first page, never an unbounded query.
  Future<List<BloodRequestModel>> getByStatus(String status) async =>
      (await getByStatusPage(status)).items;

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
