import 'package:cloud_firestore/cloud_firestore.dart';

class CommitteeAssignmentModel {
  static const Set<String> _fields = {
    'user_id',
    'term_id',
    'position',
    'active',
    'assigned_at',
    'assigned_by',
    'ended_at',
  };

  final String id;
  final String userId;
  final String termId;
  final String position;
  final bool active;
  final DateTime assignedAt;
  final String assignedBy;
  final DateTime? endedAt;

  const CommitteeAssignmentModel({
    required this.id,
    required this.userId,
    required this.termId,
    required this.position,
    required this.active,
    required this.assignedAt,
    required this.assignedBy,
    required this.endedAt,
  });

  factory CommitteeAssignmentModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final keys = map.keys.toSet();
    if (keys.length != _fields.length || !keys.containsAll(_fields)) {
      throw const FormatException(
        'CommitteeAssignment has missing or unapproved fields.',
      );
    }
    final active = _requiredBool(map, 'active');
    final endedAt = _nullableTimestamp(map, 'ended_at');
    return CommitteeAssignmentModel(
      id: _documentId(documentId),
      userId: _requiredString(map, 'user_id'),
      termId: _requiredString(map, 'term_id'),
      position: _requiredString(map, 'position'),
      active: active,
      assignedAt: _requiredTimestamp(map, 'assigned_at').toDate(),
      assignedBy: _requiredString(map, 'assigned_by'),
      endedAt: endedAt?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'term_id': termId,
    'position': position,
    'active': active,
    'assigned_at': Timestamp.fromDate(assignedAt),
    'assigned_by': assignedBy,
    'ended_at': endedAt == null ? null : Timestamp.fromDate(endedAt!),
  };

  static String _documentId(String value) {
    if (value.isEmpty || value.contains('/')) {
      throw const FormatException(
        'CommitteeAssignment document ID is invalid.',
      );
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('$key must be a bool.');
    return value;
  }

  static Timestamp _requiredTimestamp(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! Timestamp) throw FormatException('$key must be a Timestamp.');
    return value;
  }

  static Timestamp? _nullableTimestamp(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value != null && value is! Timestamp) {
      throw FormatException('$key must be a Timestamp or null.');
    }
    return value as Timestamp?;
  }
}
