import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/donor_model.dart';
import '../models/donor_submission_model.dart';

class DonorServiceException implements Exception {
  final String code;
  const DonorServiceException(this.code);
}

/// A cursor-based page of pending applications. The cursor comes from the
/// last returned document, never from a client-provided document ID.
class PendingDonorPage {
  final List<DonorSubmissionModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const PendingDonorPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class DonorService {
  final FirebaseFirestore _firestore;

  DonorService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> submitDonor({
    required DonorInput input,
    required String actorUserId,
    required String actorRole,
  }) async {
    _validateId(actorUserId, 'actor');
    if (!{
      AppConstants.roleDeveloperAdmin,
      AppConstants.roleLeader,
      AppConstants.roleExecutive,
      AppConstants.roleCommittee,
    }.contains(actorRole)) {
      throw const DonorServiceException('permission_denied');
    }

    try {
      String? assignmentId;
      if (actorRole != AppConstants.roleDeveloperAdmin) {
        final assignments = await _firestore
            .collection('committee_assignments')
            .where('user_id', isEqualTo: actorUserId)
            .where('active', isEqualTo: true)
            .limit(2)
            .get();
        if (assignments.docs.length != 1) {
          throw const DonorServiceException('committee_assignment_required');
        }
        assignmentId = assignments.docs.single.id;
      }

      final reference = _firestore
          .collection(AppConstants.donorSubmissionsCollection)
          .doc();
      await reference.set({
        'donor_payload': input.profileFields(),
        'committee_assignment_id': assignmentId,
        'submitted_by': actorUserId,
        'submitted_at': FieldValue.serverTimestamp(),
        'status': 'pending',
        'approved_by': null,
        'approved_at': null,
        'rejected_by': null,
        'rejected_at': null,
        'rejection_reason': null,
        'donor_id': null,
      });
      return reference.id;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  /// Fetch a bounded page rather than all applications in one read.
  /// The [after] snapshot is from the previous ordered page.
  Future<PendingDonorPage> getPendingSubmissionsPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw const DonorServiceException('invalid_limit');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.donorSubmissionsCollection)
          .where('status', isEqualTo: 'pending')
          .orderBy('submitted_at');
      if (after != null) query = query.startAfterDocument(after);
      // One extra document establishes whether a next page exists.
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      return PendingDonorPage(
        items: List.unmodifiable(
          docs.map((doc) => DonorSubmissionModel.fromMap(doc.data(), doc.id)),
        ),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on DonorDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  // Kept for non-paginated callers; explicit limit prevents unbounded reads.
  Future<List<DonorSubmissionModel>> getPendingSubmissions() async {
    return (await getPendingSubmissionsPage()).items;
  }

  Future<void> approveSubmission({
    required DonorSubmissionModel submission,
    required String actorUserId,
  }) async {
    _validateId(actorUserId, 'actor');
    final submissionRef = _firestore
        .collection(AppConstants.donorSubmissionsCollection)
        .doc(submission.id);
    final donorRef = _firestore
        .collection(AppConstants.donorsCollection)
        .doc(submission.id);
    try {
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(submissionRef);
        final data = current.data();
        if (!current.exists || data == null) {
          throw const DonorServiceException('submission_missing');
        }
        final parsed = DonorSubmissionModel.fromMap(data, current.id);
        if (parsed.status != 'pending') {
          throw const DonorServiceException('already_decided');
        }
        final now = FieldValue.serverTimestamp();
        transaction.set(donorRef, {
          ...parsed.donor.profileFields(),
          'linked_user_id': null,
          'active': true,
          'last_donated_at': null,
          'total_donations': 0,
          'created_at': now,
          'created_by': parsed.submittedBy,
          'updated_at': now,
          'updated_by': actorUserId,
        });
        transaction.update(submissionRef, {
          'status': 'approved',
          'approved_by': actorUserId,
          'approved_at': now,
          'donor_id': donorRef.id,
        });
      });
    } on DonorServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  Future<void> rejectSubmission({
    required DonorSubmissionModel submission,
    required String actorUserId,
    required String reason,
  }) async {
    _validateId(actorUserId, 'actor');
    if (reason.trim().isEmpty) {
      throw const DonorDataException('rejection_reason is required.');
    }
    try {
      await _firestore
          .collection(AppConstants.donorSubmissionsCollection)
          .doc(submission.id)
          .update({
            'status': 'rejected',
            'rejected_by': actorUserId,
            'rejected_at': FieldValue.serverTimestamp(),
            'rejection_reason': reason.trim(),
          });
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
