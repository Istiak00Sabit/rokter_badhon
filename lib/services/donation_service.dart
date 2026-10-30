import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/donation_model.dart';
import '../models/donor_model.dart';

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

  /// Save a verified donation and advance the donor's all-time count in
  /// one Firestore transaction. Only the approved editorial roles may call
  /// the write under the currently published Firestore Rules.
  Future<String> recordDonation({
    required String donorId,
    required String actorUserId,
    required DateTime donatedAt,
    String? hospital,
    String? location,
  }) async {
    if (donorId.isEmpty || donorId.contains('/') ||
        actorUserId.isEmpty || actorUserId.contains('/')) {
      throw const DonationServiceException('invalid_argument');
    }
    if (donatedAt.isAfter(DateTime.now())) {
      throw const DonationServiceException('invalid_donation_date');
    }
    final donorRef = _firestore.collection('donors').doc(donorId);
    final donationRef = _firestore.collection('donations').doc();
    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(donorRef);
        final data = snapshot.data();
        if (data == null) {
          throw const DonationServiceException('donor_missing');
        }
        final donor = DonorModel.fromMap(data, snapshot.id);
        if (!donor.active) {
          throw const DonationServiceException('donor_inactive');
        }
        if (donor.lastDonatedAt != null &&
            !donatedAt.isAfter(donor.lastDonatedAt!)) {
          throw const DonationServiceException('invalid_donation_date');
        }
        final now = FieldValue.serverTimestamp();
        tx.set(donationRef, {
          'donor_id': donorId,
          'donor_name_snapshot': donor.name,
          'blood_group_snapshot': donor.bloodGroup,
          'donation_date': Timestamp.fromDate(donatedAt),
          'location': location?.trim().isEmpty == true ? null : location?.trim(),
          'hospital': hospital?.trim().isEmpty == true ? null : hospital?.trim(),
          'recipient_name': null,
          'recipient_contact': null,
          'recorded_by': actorUserId,
          'created_at': now,
          'updated_at': null,
        });
        tx.update(donorRef, {
          'total_donations': donor.totalDonations + 1,
          'last_donated_at': Timestamp.fromDate(donatedAt),
          'latest_donation_id': donationRef.id,
          'updated_at': now,
          'updated_by': actorUserId,
        });
      });
      return donationRef.id;
    } on DonationServiceException {
      rethrow;
    } on DonorDataException {
      throw const DonationServiceException('malformed_data');
    } on FirebaseException catch (error) {
      throw DonationServiceException(switch (error.code) {
        'permission-denied' => 'permission_denied',
        'failed-precondition' => 'query_unavailable',
        'unavailable' || 'network-request-failed' => 'network_unavailable',
        _ => 'operation_failed',
      });
    }
  }

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
