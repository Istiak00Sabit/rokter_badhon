import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/audit_log_model.dart';
import '../models/registration_request_model.dart';

class AdministrationServiceException implements Exception {
  final String code;
  const AdministrationServiceException(this.code);
}

class AdministrationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AdministrationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<List<RegistrationRequestModel>> pendingRegistrations() async {
    try {
      final snapshot = await _firestore
          .collection('registration_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requested_at', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => RegistrationRequestModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
    } on FormatException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdministrationServiceException(_code(error));
    }
  }

  Future<void> approveRegistration({
    required RegistrationRequestModel request,
    required String actorUserId,
    required String actorRole,
  }) async {
    _requireReviewer(actorRole);
    final authUid = request.authUid;
    if (authUid.isEmpty || authUid.contains('/')) {
      throw const AdministrationServiceException('malformed_data');
    }

    final requestRef =
        _firestore.collection('registration_requests').doc(authUid);
    final userRef = _firestore.collection('users').doc(authUid);
    final directoryRef =
        _firestore.collection('user_directory').doc(authUid);
    final linkRef = _firestore.collection('auth_links').doc(authUid);

    try {
      final existingDirectory = await _firestore
          .collection('user_directory')
          .where('phone', isEqualTo: request.phone)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (existingDirectory.docs.any((doc) => doc.id != authUid)) {
        throw const AdministrationServiceException('identity_conflict');
      }

      final operationId =
          'registration-${authUid}-${DateTime.now().microsecondsSinceEpoch}';
      final auditRef =
          _firestore.collection('audit_logs').doc(operationId);
      final authUidFromFirebase = _auth.currentUser?.uid;
      if (authUidFromFirebase == null) {
        throw const AdministrationServiceException('session_unavailable');
      }

      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(requestRef);
        if (!current.exists || current.data() == null) {
          throw const AdministrationServiceException('not_found');
        }

        final parsed = RegistrationRequestModel.fromMap(
          current.data()!,
          current.id,
        );
        if (parsed.status != RegistrationRequestStatus.pending) {
          throw const AdministrationServiceException('already_decided');
        }

        final existingUser = await transaction.get(userRef);
        final existingLink = await transaction.get(linkRef);
        if (existingUser.exists || existingLink.exists) {
          throw const AdministrationServiceException('identity_conflict');
        }

        final now = FieldValue.serverTimestamp();
        final user = <String, dynamic>{
          'name': parsed.name,
          'phone': parsed.phone,
          'email': parsed.email,
          'blood_group': parsed.bloodGroup,
          'profession': parsed.profession,
          'address': parsed.address,
          'photo_url': null,
          'access_role': 'member',
          'active': true,
          'login_enabled': true,
          'preferred_language': null,
          'created_at': now,
          'created_by': actorUserId,
          'updated_at': now,
          'updated_by': actorUserId,
        };
        final directory = <String, dynamic>{
          'name': parsed.name,
          'phone': parsed.phone,
          'blood_group': parsed.bloodGroup,
          'profession': parsed.profession,
          'photo_url': null,
          'active': true,
        };
        final link = <String, dynamic>{
          'user_id': authUid,
          'active': true,
          'created_at': now,
          'created_by': actorUserId,
        };
        final decision = <String, dynamic>{
          'status': 'approved',
          'approved_by': actorUserId,
          'approved_at': now,
          'linked_user_id': authUid,
        };
        final audit = <String, dynamic>{
          'action': 'registration.approve',
          'actor_user_id': actorUserId,
          'actor_auth_uid': authUidFromFirebase,
          'target_path': requestRef.path,
          'occurred_at': now,
          'operation_id': operationId,
          'outcome': 'committed',
          'changes': {
            'status': {'before': 'pending', 'after': 'approved'},
            'linked_user_id': {'after': authUid},
            'access_role': {'after': 'member'},
            'login_enabled': {'after': true},
          },
          'reason': 'Approved from the in-app administration review screen.',
        };

        transaction.set(userRef, user);
        transaction.set(directoryRef, directory);
        transaction.set(linkRef, link);
        transaction.update(requestRef, decision);
        transaction.set(auditRef, audit);
      });
    } on AdministrationServiceException {
      rethrow;
    } on FormatException {
      throw const AdministrationServiceException('malformed_data');
    } on FirebaseException catch (error) {
      throw AdministrationServiceException(_code(error));
    }
  }

  Future<void> rejectRegistration({
    required RegistrationRequestModel request,
    required String actorUserId,
    required String actorRole,
    String? reason,
  }) async {
    _requireReviewer(actorRole);
    final authUid = request.authUid;
    if (authUid.isEmpty || authUid.contains('/')) {
      throw const AdministrationServiceException('malformed_data');
    }

    final requestRef =
        _firestore.collection('registration_requests').doc(authUid);
    final authUidFromFirebase = _auth.currentUser?.uid;
    if (authUidFromFirebase == null) {
      throw const AdministrationServiceException('session_unavailable');
    }

    final operationId =
        'registration-reject-${authUid}-${DateTime.now().microsecondsSinceEpoch}';
    final auditRef = _firestore.collection('audit_logs').doc(operationId);

    try {
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(requestRef);
        if (!current.exists || current.data() == null) {
          throw const AdministrationServiceException('not_found');
        }

        final parsed = RegistrationRequestModel.fromMap(
          current.data()!,
          current.id,
        );
        if (parsed.status != RegistrationRequestStatus.pending) {
          throw const AdministrationServiceException('already_decided');
        }

        final now = FieldValue.serverTimestamp();
        transaction.update(requestRef, {
          'status': 'rejected',
          'rejected_by': actorUserId,
          'rejected_at': now,
        });
        transaction.set(auditRef, {
          'action': 'registration.reject',
          'actor_user_id': actorUserId,
          'actor_auth_uid': authUidFromFirebase,
          'target_path': requestRef.path,
          'occurred_at': now,
          'operation_id': operationId,
          'outcome': 'committed',
          'changes': {
            'status': {'before': 'pending', 'after': 'rejected'},
          },
          'reason': (reason == null || reason.trim().isEmpty)
              ? 'Rejected from the in-app administration review screen.'
              : reason.trim(),
        });
      });
    } on AdministrationServiceException {
      rethrow;
    } on FormatException {
      throw const AdministrationServiceException('malformed_data');
    } on FirebaseException catch (error) {
      throw AdministrationServiceException(_code(error));
    }
  }

  Future<List<AuditLogModel>> auditLogs({int limit = 100}) async {
    if (limit < 1 || limit > 200) {
      throw const AdministrationServiceException('invalid_limit');
    }
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .orderBy('occurred_at', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
    } on FormatException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdministrationServiceException(_code(error));
    }
  }

  void _requireReviewer(String role) {
    if (!{'developer_admin', 'admin', 'leader'}.contains(role)) {
      throw const AdministrationServiceException('permission_denied');
    }
  }
}

String _code(FirebaseException error) => switch (error.code) {
  'permission-denied' => 'permission_denied',
  'unavailable' => 'unavailable',
  'failed-precondition' => 'index_required',
  'already-exists' => 'identity_conflict',
  'not-found' => 'not_found',
  _ => 'firestore_error',
};
