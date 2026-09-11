import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_model.dart';

class EventMediaModel {
  static const fields = <String>{
    'event_id',
    'image_url',
    'caption',
    'sort_order',
    'active',
    'uploaded_at',
    'uploaded_by',
    'provider',
    'provider_public_id',
  };

  final String id;
  final String eventId;
  final String imageUrl;
  final String? caption;
  final int sortOrder;
  final bool active;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? provider;
  final String? providerPublicId;

  const EventMediaModel({
    required this.id,
    required this.eventId,
    required this.imageUrl,
    required this.caption,
    required this.sortOrder,
    required this.active,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.provider,
    required this.providerPublicId,
  });

  factory EventMediaModel.fromMap(Map<String, dynamic> map, String id) {
    if (id.isEmpty || id.contains('/')) {
      throw const EventDataException('Invalid media ID.');
    }
    final keys = map.keys.toSet();
    if (keys.difference(fields).isNotEmpty ||
        fields.difference(keys).isNotEmpty) {
      throw const EventDataException(
        'EventMedia has missing or unapproved fields.',
      );
    }
    String requiredText(dynamic value, String field) {
      if (value is! String || value.isEmpty) {
        throw EventDataException('$field must be non-empty.');
      }
      return value;
    }

    String? optionalText(dynamic value, String field, int max) {
      if (value == null) return null;
      if (value is! String || value.isEmpty || value.length > max) {
        throw EventDataException('$field must be a bounded string or null.');
      }
      return value;
    }

    final eventId = requiredText(map['event_id'], 'event_id');
    final imageUrl = requiredText(map['image_url'], 'image_url');
    final uri = Uri.tryParse(imageUrl);
    if (eventId.contains('/') ||
        imageUrl.length > 2048 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const EventDataException(
        'EventMedia identity or image URL is invalid.',
      );
    }
    final order = map['sort_order'];
    if (order is! int || order < 0) {
      throw const EventDataException('sort_order must be nonnegative.');
    }
    if (map['active'] is! bool || map['uploaded_at'] is! Timestamp) {
      throw const EventDataException(
        'EventMedia state or timestamp is malformed.',
      );
    }
    final uploadedBy = requiredText(map['uploaded_by'], 'uploaded_by');
    if (uploadedBy.contains('/')) {
      throw const EventDataException('uploaded_by is invalid.');
    }
    final provider = optionalText(map['provider'], 'provider', 200);
    final publicId = optionalText(
      map['provider_public_id'],
      'provider_public_id',
      512,
    );
    if (publicId != null && provider == null) {
      throw const EventDataException('provider_public_id requires provider.');
    }
    return EventMediaModel(
      id: id,
      eventId: eventId,
      imageUrl: imageUrl,
      caption: optionalText(map['caption'], 'caption', 200),
      sortOrder: order,
      active: map['active'] as bool,
      uploadedAt: (map['uploaded_at'] as Timestamp).toDate(),
      uploadedBy: uploadedBy,
      provider: provider,
      providerPublicId: publicId,
    );
  }
}
