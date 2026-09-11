import 'package:cloud_firestore/cloud_firestore.dart';

class EventDataException implements Exception {
  final String message;
  const EventDataException(this.message);
  @override
  String toString() => message;
}

class EventModel {
  static const eventTypes = <String>{
    'meeting',
    'blood_donation_campaign',
    'awareness_program',
    'social_activity',
    'celebration',
    'emergency_activity',
    'other',
  };
  static const fields = <String>{
    'title',
    'description',
    'event_type',
    'event_date',
    'location',
    'cover_image_url',
    'active',
    'created_at',
    'created_by',
    'updated_at',
    'updated_by',
  };

  final String id;
  final String title;
  final String? description;
  final String eventType;
  final DateTime eventDate;
  final String? location;
  final String? coverImageUrl;
  final bool active;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    required this.eventDate,
    required this.location,
    required this.coverImageUrl,
    required this.active,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    _id(id, 'event ID');
    _exact(map, fields, 'Event');
    final type = _text(map['event_type'], 'event_type');
    if (!eventTypes.contains(type)) {
      throw const EventDataException('Event has an unknown event_type.');
    }
    final updatedAt = _nullableTimestamp(map['updated_at'], 'updated_at');
    final updatedBy = _nullableId(map['updated_by'], 'updated_by');
    if ((updatedAt == null) != (updatedBy == null)) {
      throw const EventDataException('Event update metadata is inconsistent.');
    }
    return EventModel(
      id: id,
      title: _boundedText(map['title'], 'title', 200),
      description: _nullableBoundedText(
        map['description'],
        'description',
        5000,
      ),
      eventType: type,
      eventDate: _timestamp(map['event_date'], 'event_date'),
      location: _nullableBoundedText(map['location'], 'location', 300),
      coverImageUrl: _nullableHttps(map['cover_image_url'], 'cover_image_url'),
      active: _bool(map['active'], 'active'),
      createdAt: _timestamp(map['created_at'], 'created_at'),
      createdBy: _id(map['created_by'], 'created_by'),
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }

  static String typeTranslationKey(String key) =>
      eventTypes.contains(key) ? 'event_type.$key' : 'unknown';
}

void _exact(Map<String, dynamic> value, Set<String> fields, String label) {
  final keys = value.keys.toSet();
  if (keys.difference(fields).isNotEmpty ||
      fields.difference(keys).isNotEmpty) {
    throw EventDataException('$label has missing or unapproved fields.');
  }
}

String _text(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw EventDataException('$field must be a non-empty string.');
  }
  return value.trim();
}

String _boundedText(dynamic value, String field, int max) {
  final result = _text(value, field);
  if (result.length > max) throw EventDataException('$field is too long.');
  return result;
}

String? _nullableBoundedText(dynamic value, String field, int max) {
  if (value == null) return null;
  return _boundedText(value, field, max);
}

String _id(dynamic value, String field) {
  final result = _text(value, field);
  if (result.contains('/')) throw EventDataException('$field is invalid.');
  return result;
}

String? _nullableId(dynamic value, String field) =>
    value == null ? null : _id(value, field);

bool _bool(dynamic value, String field) {
  if (value is! bool) throw EventDataException('$field must be boolean.');
  return value;
}

DateTime _timestamp(dynamic value, String field) {
  if (value is! Timestamp) {
    throw EventDataException('$field must be a Firestore Timestamp.');
  }
  return value.toDate();
}

DateTime? _nullableTimestamp(dynamic value, String field) =>
    value == null ? null : _timestamp(value, field);

String? _nullableHttps(dynamic value, String field) {
  if (value == null) return null;
  if (value is! String || value.isEmpty || value.length > 2048) {
    throw EventDataException('$field must be an HTTPS URL or null.');
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw EventDataException('$field must be an HTTPS URL or null.');
  }
  return value;
}
