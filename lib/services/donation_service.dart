import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/donation_model.dart';

class DonationServiceException implements Exception {
  final String code;
  const DonationServiceException(this.code);
}

/// A bounded, ordered page. A Firestore snapshot cursor avoids unstable
/// offset pagination when multiple donation records share a donation date.
class DonationPage {
  final List<DonationModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const DonationPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class DonationService {
  final FirebaseFirestore _firestore;
  DonationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<DonationPage> getHistoryPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw const DonationServiceException('invalid_limit');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('donations')
          .orderBy('donation_date', descending: true);
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      return DonationPage(
        items: List<DonationModel>.unmodifiable(
          docs.map((doc) => DonationModel.fromMap(doc.data(), doc.id)),
        ),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on DonationDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonationServiceException(switch (error.code) {
        'permission-denied' => 'permission_denied',
        'failed-precondition' => 'query_unavailable',
        'unavailable' || 'network-request-failed' => 'network_unavailable',
        _ => 'operation_failed',
      });
    }
  }

  // Legacy call sites still get a bounded first page rather than an
  // accidentally unbounded history download.
  Future<List<DonationModel>> getHistory() async =>
      (await getHistoryPage()).items;
}
