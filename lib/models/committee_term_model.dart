import 'package:cloud_firestore/cloud_firestore.dart';

class CommitteeTermModel {
  static const Set<String> _fields = {
    'name',
    'start_year',
    'end_year',
    'start_date',
    'end_date',
    'active',
    'group_photo_url',
    'created_at',
    'created_by',
  };

  final String id;
  final String name;
  final num startYear;
  final num endYear;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final String? groupPhotoUrl;
  final DateTime createdAt;
  final String createdBy;

  const CommitteeTermModel({
    required this.id,
    required this.name,
    required this.startYear,
    required this.endYear,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.groupPhotoUrl,
    required this.createdAt,
    required this.createdBy,
  });

  factory CommitteeTermModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    _requireExactFields(map, _fields);
    final startYear = _requiredNumber(map, 'start_year');
    final endYear = _requiredNumber(map, 'end_year');
    return CommitteeTermModel(
      id: _documentId(documentId),
      name: _requiredString(map, 'name'),
      startYear: startYear,
      endYear: endYear,
      startDate: _nullableTimestamp(map, 'start_date')?.toDate(),
      endDate: _nullableTimestamp(map, 'end_date')?.toDate(),
      active: _requiredBool(map, 'active'),
      groupPhotoUrl: _nullableHttpsUrl(map, 'group_photo_url'),
      createdAt: _requiredTimestamp(map, 'created_at').toDate(),
      createdBy: _requiredString(map, 'created_by'),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'start_year': startYear,
    'end_year': endYear,
    'start_date': startDate == null ? null : Timestamp.fromDate(startDate!),
    'end_date': endDate == null ? null : Timestamp.fromDate(endDate!),
    'active': active,
    'group_photo_url': groupPhotoUrl,
    'created_at': Timestamp.fromDate(createdAt),
    'created_by': createdBy,
  };

  static void _requireExactFields(
    Map<String, dynamic> map,
    Set<String> fields,
  ) {
    final keys = map.keys.toSet();
    if (keys.length != fields.length || !keys.containsAll(fields)) {
      throw const FormatException(
        'CommitteeTerm has missing or unapproved fields.',
      );
    }
  }

  static String _documentId(String value) {
    if (value.isEmpty || value.contains('/')) {
      throw const FormatException('CommitteeTerm document ID is invalid.');
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static num _requiredNumber(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num) throw FormatException('$key must be a number.');
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

  static String? _nullableHttpsUrl(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw FormatException('$key must be a string or null.');
    }
    if (value is String &&
        (value.length > 2048 ||
            !RegExp(r'^https://[^/]+.*$').hasMatch(value))) {
      throw FormatException('$key must be a valid HTTPS URL or null.');
    }
    return value as String?;
  }
}
