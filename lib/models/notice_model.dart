import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeDataException implements Exception {
  final String message;
  const NoticeDataException(this.message);
}

class NoticeModel {
  static const fields = <String>{
    'title',
    'body',
    'important',
    'status',
    'created_by',
    'created_at',
    'updated_by',
    'updated_at',
  };
  final String id;
  final String title;
  final String body;
  final bool important;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const NoticeModel({
    required this.id,
    required this.title,
    required this.body,
    required this.important,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory NoticeModel.fromMap(Map<String, dynamic> map, String id) {
    _id(id, 'notice ID');
    final keys = map.keys.toSet();
    if (keys.difference(fields).isNotEmpty ||
        fields.difference(keys).isNotEmpty) {
      throw const NoticeDataException(
        'Notice has missing or unapproved fields.',
      );
    }
    final status = _text(map['status'], 'status');
    if (!{'draft', 'published', 'archived'}.contains(status)) {
      throw const NoticeDataException('Notice status is unknown.');
    }
    if (map['important'] is! bool) {
      throw const NoticeDataException('important must be boolean.');
    }
    final updatedBy = _nullableId(map['updated_by'], 'updated_by');
    final updatedAt = _nullableTimestamp(map['updated_at'], 'updated_at');
    if ((updatedBy == null) != (updatedAt == null)) {
      throw const NoticeDataException(
        'Notice update metadata is inconsistent.',
      );
    }
    return NoticeModel(
      id: id,
      title: _text(map['title'], 'title'),
      body: _text(map['body'], 'body'),
      important: map['important'] as bool,
      status: status,
      createdBy: _id(map['created_by'], 'created_by'),
      createdAt: _timestamp(map['created_at'], 'created_at'),
      updatedBy: updatedBy,
      updatedAt: updatedAt,
    );
  }
}

String _text(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw NoticeDataException('$field must be non-empty.');
  }
  return value.trim();
}

String _id(dynamic value, String field) {
  final result = _text(value, field);
  if (result.contains('/')) throw NoticeDataException('$field is invalid.');
  return result;
}

String? _nullableId(dynamic value, String field) =>
    value == null ? null : _id(value, field);
DateTime _timestamp(dynamic value, String field) {
  if (value is! Timestamp) {
    throw NoticeDataException('$field must be a Firestore Timestamp.');
  }
  return value.toDate();
}

DateTime? _nullableTimestamp(dynamic value, String field) =>
    value == null ? null : _timestamp(value, field);
