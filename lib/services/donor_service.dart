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

/// A bounded active donor directory page. Only scanned/loaded records are
/// searchable locally until the user requests remaining pages.
class ActiveDonorPage {
  final List<DonorModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const ActiveDonorPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class DonorService {
  final FirebaseFirestore _firestore;

  DonorService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Detect already-active records with the same exact stored phone.
  /// This is a safety preflight, NOT a transactional uniqueness constraint
  /// across distinct simultaneous submissions. A trusted phone-identity index
  /// and migration are required before promising global uniqueness.
  Future<void> assertNoActivePhoneConflict(
    String phone, {
    String? excludingDonorId,
  }) async {
    if (phone.trim().isEmpty) {
      throw const DonorDataException('phone must be non-empty.');
    }
    try {
      final snapshot = await _firestore
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true)
          .where('phone', isEqualTo: phone.trim())
          .limit(2)
          .get();
      if (snapshot.docs.any((doc) => doc.id != excludingDonorId)) {
        throw const DonorServiceException('duplicate_donor');
      }
    } on DonorServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  /// Canonical Bangladesh mobile identity for submissions and reservations.
  static String canonicalDonorPhone(String value) {
    final digits = '০১২৩৪৫৬৭৮৯';
    final ascii = value.trim().split('').map((ch) {
      final index = digits.indexOf(ch);
      return index < 0 ? ch : index.toString();
    }).join().replaceAll(RegExp(r'[\s-]'), '');
    final phone = ascii.startsWith('+880')
        ? '0${ascii.substring(4)}'
        : ascii.startsWith('880')
            ? '0${ascii.substring(3)}'
            : ascii;
    if (!RegExp(r'^01[3-9][0-9]{8}$').hasMatch(phone)) {
      throw const DonorDataException('Invalid complete Bangladesh mobile phone.');
    }
    return phone;
  }
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
      final fields = input.profileFields();
      fields['phone'] = canonicalDonorPhone(input.phone);
      await assertNoActivePhoneConflict(fields['phone'] as String);
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
        'donor_payload': fields,
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

  /// Approve an already saved submission through the existing audited flow.
  /// When approval fails, the original submission stays pending.
  Future<void> approveSubmittedDonor({
    required String submissionId,
    required String actorUserId,
  }) async {
    _validateId(submissionId, 'submission');
    try {
      final snapshot = await _firestore
          .collection(AppConstants.donorSubmissionsCollection)
          .doc(submissionId)
          .get();
      final data = snapshot.data();
      if (data == null) {
        throw const DonorServiceException('submission_missing');
      }
      await approveSubmission(
        submission: DonorSubmissionModel.fromMap(data, snapshot.id),
        actorUserId: actorUserId,
      );
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

  /// Historical donor decisions remain in Firestore with their status,
  /// reviewer and rejection reason; they are not live donors when rejected.
  Future<List<DonorSubmissionModel>> getReviewedSubmissions({
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 100) {
      throw const DonorServiceException('invalid_limit');
    }
    try {
      final snapshot = await _firestore
          .collection(AppConstants.donorSubmissionsCollection)
          .where('status', whereIn: ['approved', 'rejected'])
          .limit(limit)
          .get();
      final items = snapshot.docs
          .map((doc) => DonorSubmissionModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      items.sort((a, b) => (b.approvedAt ?? b.rejectedAt ?? b.submittedAt)
          .compareTo(a.approvedAt ?? a.rejectedAt ?? a.submittedAt));
      return items;
    } on DonorDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
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
      final phone = canonicalDonorPhone(submission.donor.phone);
      if (submission.donor.phone != phone) {
        throw const DonorServiceException('donor_phone_migration_required');
      }
      // A legacy preflight improves errors but does not provide locking.
      await assertNoActivePhoneConflict(phone);
      final keyRef = _firestore.collection('donor_phone_keys').doc(phone);
      final registryRef =
          _firestore.collection('system_config').doc('donor_phone_registry');
      await _firestore.runTransaction((transaction) async {
        // All reads precede writes. A deterministic key is the lock.
        final registry = await transaction.get(registryRef);
        final current = await transaction.get(submissionRef);
        final existingDonor = await transaction.get(donorRef);
        final existingKey = await transaction.get(keyRef);
        if (registry.data()?['ready'] != true ||
            registry.data()?['schema_version'] != 1) {
          throw const DonorServiceException('donor_registry_not_ready');
        }
        if (existingDonor.exists || existingKey.exists) {
          throw const DonorServiceException('duplicate_donor');
        }
        final data = current.data();
        if (!current.exists || data == null) {
          throw const DonorServiceException('submission_missing');
        }
        final parsed = DonorSubmissionModel.fromMap(data, current.id);
        if (parsed.status != 'pending') {
          throw const DonorServiceException('already_decided');
        }
        if (parsed.donor.phone != phone) {
          throw const DonorServiceException('submission_changed');
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
        transaction.set(keyRef, {
          'phone': phone,
          'donor_id': donorRef.id,
          'reserved_at': now,
          'reserved_by': actorUserId,
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
      final fields = input.profileFields();
      final ref = _firestore.collection(AppConstants.donorsCollection).doc(donorId);
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(ref);
        if (!current.exists || current.data() == null) {
          throw const DonorServiceException('donor_missing');
        }
        final persisted = DonorModel.fromMap(current.data()!, current.id);
        if (!persisted.active) {
          throw const DonorServiceException('donor_inactive');
        }
        // Changing phone identity requires a separately reviewed re-key.
        if (fields['phone'] != persisted.phone) {
          throw const DonorServiceException('donor_phone_change_locked');
        }
        transaction.update(ref, {
          ...fields,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': actorUserId,
        });
      });
    } on DonorServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }
  Future<ActiveDonorPage> getActiveDonorsPage({
    String? bloodGroup,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw const DonorServiceException('invalid_limit');
    }
    if (bloodGroup != null &&
        !AppConstants.bloodGroups.contains(bloodGroup)) {
      throw const DonorDataException('Unknown blood group filter.');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true);
      if (bloodGroup != null) {
        query = query.where('blood_group', isEqualTo: bloodGroup);
      }
      query = query.orderBy('name');
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      final values = docs
          .map((doc) => DonorModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (values.any((item) =>
          !item.active ||
          (bloodGroup != null && item.bloodGroup != bloodGroup))) {
        throw const DonorDataException(
          'Donor query returned an unapproved record.',
        );
      }
      return ActiveDonorPage(
        items: List<DonorModel>.unmodifiable(values),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on DonorDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  /// Canonicalize a *complete* Bangladeshi phone; null means name search.
  /// Invalid partial/other numeric queries fail instead of returning false
  /// negatives from a misleading "whole directory" search.
  static String? normalizeSearchPhone(String search) {
    final term = search.trim();
    if (!RegExp(r'^[+0-9\s-]+$').hasMatch(term)) return null;
    final compact = term.replaceAll(RegExp(r'[\s-]'), '');
    final phone = compact.startsWith('+880')
        ? '0${compact.substring(4)}'
        : compact.startsWith('880')
            ? '0${compact.substring(3)}'
            : compact;
    if (!RegExp(r'^01[3-9][0-9]{8}$').hasMatch(phone)) {
      throw const DonorDataException('Use a complete BD mobile phone number.');
    }
    return phone;
  }

  /// Exact normalized BD-phone lookup or case-sensitive name-prefix lookup.
  /// Indexed across the complete chosen active directory, with cursor paging.
  /// Does NOT pretend to support arbitrary substring or fuzzy matching.
  Future<ActiveDonorPage> searchActiveDonorsPage({
    required String search,
    String? bloodGroup,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    final term = search.trim();
    if (term.isEmpty || term.length > 80) {
      throw const DonorDataException('Search must be non-empty and bounded.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw const DonorServiceException('invalid_limit');
    }
    if (bloodGroup != null && !AppConstants.bloodGroups.contains(bloodGroup)) {
      throw const DonorDataException('Unknown blood group filter.');
    }
    final phone = normalizeSearchPhone(term);
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true);
      if (bloodGroup != null) {
        query = query.where('blood_group', isEqualTo: bloodGroup);
      }
      if (phone != null) {
        query = query.where('phone', isEqualTo: phone).orderBy('name');
      } else {
        query = query.orderBy('name')
            .startAt([term]).endAt(['$term\uf8ff']);
      }
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      final donors = docs
          .map((doc) => DonorModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (donors.any((donor) => !donor.active ||
          (bloodGroup != null && donor.bloodGroup != bloodGroup) ||
          (phone != null ? donor.phone != phone : !donor.name.startsWith(term)))) {
        throw const DonorDataException('Indexed donor search returned an unapproved record.');
      }
      return ActiveDonorPage(
        items: List<DonorModel>.unmodifiable(donors),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on DonorDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw DonorServiceException(_safeCode(error.code));
    }
  }

  /// Compatibility API: one bounded page, not a full-directory search.
  Future<List<DonorModel>> getAllDonors() async =>
      (await getActiveDonorsPage()).items;

  Future<List<DonorModel>> getDonorsByBloodGroup(String bloodGroup) async =>
      (await getActiveDonorsPage(bloodGroup: bloodGroup)).items;

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
