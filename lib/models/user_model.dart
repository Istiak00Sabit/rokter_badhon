import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  static const Set<String> allowedAccessRoles = {
    'developer_admin',
    'leader',
    'executive',
    'committee',
    'member',
  };
  static const Set<String> _fields = {
    'name',
    'phone',
    'email',
    'blood_group',
    'profession',
    'address',
    'photo_url',
    'access_role',
    'active',
    'login_enabled',
    'preferred_language',
    'created_at',
    'created_by',
    'updated_at',
    'updated_by',
  };

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? bloodGroup;
  final String? profession;
  final String? address;
  final String? photoUrl;
  final String accessRole;
  final bool active;
  final bool loginEnabled;
  final String? preferredLanguage;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.bloodGroup,
    required this.profession,
    required this.address,
    required this.photoUrl,
    required this.accessRole,
    required this.active,
    required this.loginEnabled,
    required this.preferredLanguage,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  bool get hasRecognizedAccessRole => allowedAccessRoles.contains(accessRole);

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    _requireExactFields(map, _fields, 'User');
    return UserModel(
      id: documentId,
      name: _requiredString(map, 'name'),
      phone: _requiredString(map, 'phone'),
      email: _nullableString(map, 'email'),
      bloodGroup: _nullableString(map, 'blood_group'),
      profession: _nullableString(map, 'profession'),
      address: _nullableString(map, 'address'),
      photoUrl: _nullableHttpsUrl(map, 'photo_url'),
      accessRole: _requiredString(map, 'access_role'),
      active: _requiredBool(map, 'active'),
      loginEnabled: _requiredBool(map, 'login_enabled'),
      preferredLanguage: _nullableString(map, 'preferred_language'),
      createdAt: _requiredTimestamp(map, 'created_at').toDate(),
      createdBy: _nullableString(map, 'created_by'),
      updatedAt: _requiredTimestamp(map, 'updated_at').toDate(),
      updatedBy: _nullableString(map, 'updated_by'),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    Object? email = _unchanged,
    Object? bloodGroup = _unchanged,
    Object? profession = _unchanged,
    Object? address = _unchanged,
    Object? photoUrl = _unchanged,
    String? accessRole,
    bool? active,
    bool? loginEnabled,
    Object? preferredLanguage = _unchanged,
    DateTime? createdAt,
    Object? createdBy = _unchanged,
    DateTime? updatedAt,
    Object? updatedBy = _unchanged,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: identical(email, _unchanged) ? this.email : email as String?,
      bloodGroup: identical(bloodGroup, _unchanged)
          ? this.bloodGroup
          : bloodGroup as String?,
      profession: identical(profession, _unchanged)
          ? this.profession
          : profession as String?,
      address: identical(address, _unchanged)
          ? this.address
          : address as String?,
      photoUrl: identical(photoUrl, _unchanged)
          ? this.photoUrl
          : photoUrl as String?,
      accessRole: accessRole ?? this.accessRole,
      active: active ?? this.active,
      loginEnabled: loginEnabled ?? this.loginEnabled,
      preferredLanguage: identical(preferredLanguage, _unchanged)
          ? this.preferredLanguage
          : preferredLanguage as String?,
      createdAt: createdAt ?? this.createdAt,
      createdBy: identical(createdBy, _unchanged)
          ? this.createdBy
          : createdBy as String?,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: identical(updatedBy, _unchanged)
          ? this.updatedBy
          : updatedBy as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'email': email,
    'blood_group': bloodGroup,
    'profession': profession,
    'address': address,
    'photo_url': photoUrl,
    'access_role': accessRole,
    'active': active,
    'login_enabled': loginEnabled,
    'preferred_language': preferredLanguage,
    'created_at': Timestamp.fromDate(createdAt),
    'created_by': createdBy,
    'updated_at': Timestamp.fromDate(updatedAt),
    'updated_by': updatedBy,
  };

  static const Object _unchanged = Object();
}

void _requireExactFields(
  Map<String, dynamic> map,
  Set<String> fields,
  String model,
) {
  final keys = map.keys.toSet();
  if (keys.length != fields.length || !keys.containsAll(fields)) {
    throw FormatException('$model has missing or unapproved fields.');
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

String? _nullableString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value != null && value is! String) {
    throw FormatException('$key must be a string or null.');
  }
  return value as String?;
}

String? _nullableHttpsUrl(Map<String, dynamic> map, String key) {
  final value = _nullableString(map, key);
  if (value != null &&
      (value.length > 2048 || !RegExp(r'^https://[^/]+.*$').hasMatch(value))) {
    throw FormatException('$key must be a valid HTTPS URL or null.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! bool) throw FormatException('$key must be a bool.');
  return value;
}

Timestamp _requiredTimestamp(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Timestamp) throw FormatException('$key must be a Timestamp.');
  return value;
}
