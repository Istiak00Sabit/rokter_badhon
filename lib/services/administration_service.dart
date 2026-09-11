import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/audit_log_model.dart';
import '../models/registration_request_model.dart';

class AdministrationServiceException implements Exception {
  final String code;
  const AdministrationServiceException(this.code);
}

class AdministrationService {
  final FirebaseFirestore _firestore;
  AdministrationService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<RegistrationRequestModel>> pendingRegistrations() async {
    try {
      final snapshot = await _firestore.collection('registration_requests').where('status', isEqualTo: 'pending').orderBy('requested_at', descending: true).get();
      return snapshot.docs.map((doc) => RegistrationRequestModel.fromMap(doc.data(), doc.id)).toList(growable: false);
    } on FormatException { rethrow; } on FirebaseException catch (error) { throw AdministrationServiceException(_code(error)); }
  }

  Future<List<AuditLogModel>> auditLogs({int limit = 100}) async {
    if (limit < 1 || limit > 200) throw const AdministrationServiceException('invalid_limit');
    try {
      final snapshot = await _firestore.collection('audit_logs').orderBy('occurred_at', descending: true).limit(limit).get();
      return snapshot.docs.map((doc) => AuditLogModel.fromMap(doc.data(), doc.id)).toList(growable: false);
    } on FormatException { rethrow; } on FirebaseException catch (error) { throw AdministrationServiceException(_code(error)); }
  }
}

String _code(FirebaseException error) => switch (error.code) { 'permission-denied' => 'permission_denied', 'unavailable' => 'unavailable', 'failed-precondition' => 'index_required', _ => 'firestore_error' };
