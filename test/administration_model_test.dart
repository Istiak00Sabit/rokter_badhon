import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/audit_log_model.dart';
import 'package:rokter_badhon/models/registration_request_model.dart';

void main() {
  test('pending registration schema parses exact Timestamp state', () {
    final value = RegistrationRequestModel.fromMap({
      'auth_uid': 'auth-1', 'name': 'Applicant', 'phone': '019', 'email': 'a@example.test', 'status': 'pending',
      'requested_at': Timestamp.fromMillisecondsSinceEpoch(1), 'approved_by': null, 'approved_at': null,
      'rejected_by': null, 'rejected_at': null, 'linked_user_id': null,
    }, 'auth-1');
    expect(value.status, RegistrationRequestStatus.pending);
    expect(() => RegistrationRequestModel.fromMap({
      'auth_uid': 'auth-1', 'name': 'Applicant', 'phone': '019', 'email': 'a@example.test', 'status': 'pending',
      'requested_at': '2026-01-01', 'approved_by': null, 'approved_at': null, 'rejected_by': null, 'rejected_at': null, 'linked_user_id': null,
    }, 'auth-1'), throwsFormatException);
  });

  test('audit parser requires exact schema and Firestore Timestamp', () {
    final map = <String, dynamic>{
      'action': 'user.disable', 'actor_user_id': 'user-1', 'actor_auth_uid': 'auth-1', 'target_path': 'users/user-2',
      'occurred_at': Timestamp.fromMillisecondsSinceEpoch(1), 'operation_id': 'operation-1', 'outcome': 'committed', 'changes': <String, dynamic>{}, 'reason': 'Reviewed',
    };
    expect(AuditLogModel.fromMap(map, 'operation-1').action, 'user.disable');
    expect(() => AuditLogModel.fromMap({...map, 'secret': 'x'}, 'operation-1'), throwsFormatException);
    expect(() => AuditLogModel.fromMap({...map, 'occurred_at': 'now'}, 'operation-1'), throwsFormatException);
  });

  test('administration reads are role-scoped queries and Flutter has no writes', () {
    final service = File('lib/services/administration_service.dart').readAsStringSync();
    expect(service, contains("where('status', isEqualTo: 'pending')"));
    expect(service, contains("orderBy('requested_at', descending: true)"));
    expect(service, contains("collection('audit_logs').orderBy('occurred_at', descending: true)"));
    expect(service, isNot(contains('.add(')));
    expect(service, isNot(contains('.set(')));
    expect(service, isNot(contains('.update(')));
    expect(service, isNot(contains('.delete(')));
  });
}
