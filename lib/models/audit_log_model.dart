import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  static const fields = {'action', 'actor_user_id', 'actor_auth_uid', 'target_path', 'occurred_at', 'operation_id', 'outcome', 'changes', 'reason'};
  final String id;
  final String action;
  final String actorUserId;
  final String actorAuthUid;
  final String targetPath;
  final DateTime occurredAt;
  final String operationId;
  final String outcome;
  final Map<String, dynamic> changes;
  final String? reason;

  const AuditLogModel({required this.id, required this.action, required this.actorUserId, required this.actorAuthUid, required this.targetPath, required this.occurredAt, required this.operationId, required this.outcome, required this.changes, required this.reason});

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String id) {
    if (map.keys.toSet().length != fields.length || !map.keys.toSet().containsAll(fields)) throw const FormatException('Audit log has missing or unapproved fields.');
    final occurredAt = map['occurred_at']; final changes = map['changes']; final reason = map['reason'];
    if (occurredAt is! Timestamp) throw const FormatException('occurred_at must be a Timestamp.');
    if (changes is! Map<String, dynamic>) throw const FormatException('changes must be a string-keyed map.');
    if (reason != null && reason is! String) throw const FormatException('reason must be a string or null.');
    return AuditLogModel(
      id: _id(id, 'audit ID'), action: _text(map['action'], 'action'), actorUserId: _id(map['actor_user_id'], 'actor_user_id'),
      actorAuthUid: _id(map['actor_auth_uid'], 'actor_auth_uid'), targetPath: _path(map['target_path']), occurredAt: occurredAt.toDate(),
      operationId: _id(map['operation_id'], 'operation_id'), outcome: _text(map['outcome'], 'outcome'), changes: Map.unmodifiable(changes), reason: reason as String?,
    );
  }
}
String _text(Object? value, String field) { if (value is! String || value.trim().isEmpty) throw FormatException('$field must be non-empty.'); return value.trim(); }
String _id(Object? value, String field) { final result = _text(value, field); if (result.contains('/')) throw FormatException('$field is invalid.'); return result; }
String _path(Object? value) { final result = _text(value, 'target_path'); if (!result.contains('/') || result.startsWith('/') || result.endsWith('/')) throw const FormatException('target_path is invalid.'); return result; }
