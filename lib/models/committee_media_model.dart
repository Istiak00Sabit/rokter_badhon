import 'package:cloud_firestore/cloud_firestore.dart';

class CommitteeMediaModel {
  static const Set<String> _fields = {
    'term_id',
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
  final String termId;
  final String imageUrl;
  final String? caption;
  final int sortOrder;
  final bool active;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? provider;
  final String? providerPublicId;

  const CommitteeMediaModel({
    required this.id,
    required this.termId,
    required this.imageUrl,
    required this.caption,
    required this.sortOrder,
    required this.active,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.provider,
    required this.providerPublicId,
  });

  factory CommitteeMediaModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final keys = map.keys.toSet();
    if (keys.length != _fields.length || !keys.containsAll(_fields)) {
      throw const FormatException(
        'CommitteeMedia has missing or unapproved fields.',
      );
    }
    final provider = _nullableString(map, 'provider');
    final providerPublicId = _nullableString(map, 'provider_public_id');
    if (providerPublicId != null && provider == null) {
      throw const FormatException('provider_public_id requires a provider.');
    }
    final sortOrder = map['sort_order'];
    if (sortOrder is! int || sortOrder < 0) {
      throw const FormatException('sort_order must be a nonnegative integer.');
    }
    return CommitteeMediaModel(
      id: _documentId(documentId),
      termId: _documentId(_requiredString(map, 'term_id')),
      imageUrl: _requiredHttpsUrl(map, 'image_url'),
      caption: _nullableString(map, 'caption'),
      sortOrder: sortOrder,
      active: _requiredBool(map, 'active'),
      uploadedAt: _requiredTimestamp(map, 'uploaded_at').toDate(),
      uploadedBy: _documentId(_requiredString(map, 'uploaded_by')),
      provider: provider,
      providerPublicId: providerPublicId,
    );
  }

  Map<String, dynamic> toMap() => {
    'term_id': termId,
    'image_url': imageUrl,
    'caption': caption,
    'sort_order': sortOrder,
    'active': active,
    'uploaded_at': Timestamp.fromDate(uploadedAt),
    'uploaded_by': uploadedBy,
    'provider': provider,
    'provider_public_id': providerPublicId,
  };

  static String _documentId(String value) {
    if (value.isEmpty || value.contains('/')) {
      throw const FormatException('CommitteeMedia document ID is invalid.');
    }
    return value;
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _nullableString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw FormatException('$key must be a string or null.');
    }
    return value as String?;
  }

  static String _requiredHttpsUrl(Map<String, dynamic> map, String key) {
    final value = _requiredString(map, key);
    if (value.length > 2048 || !RegExp(r'^https://[^/]+.*$').hasMatch(value)) {
      throw FormatException('$key must be a valid HTTPS URL.');
    }
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
}
