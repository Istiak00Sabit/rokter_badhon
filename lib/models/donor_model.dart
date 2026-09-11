import 'package:cloud_firestore/cloud_firestore.dart';

class DonorDataException implements Exception {
  final String message;
  const DonorDataException(this.message);
  @override
  String toString() => message;
}

class DonorInput {
  final String name;
  final String phone;
  final String bloodGroup;
  final String? gender;
  final String? photoUrl;
  final String? village;
  final String? union;
  final String upazila;
  final String district;
  final String? profession;

  const DonorInput({
    required this.name,
    required this.phone,
    required this.bloodGroup,
    this.gender,
    this.photoUrl,
    this.village,
    this.union,
    required this.upazila,
    required this.district,
    this.profession,
  });

  Map<String, dynamic> profileFields() => {
    'name': _requiredText(name, 'name'),
    'phone': _requiredText(phone, 'phone'),
    'blood_group': _requiredText(bloodGroup, 'blood_group'),
    'gender': _optionalText(gender, 'gender'),
    'photo_url': _optionalHttpsUrl(photoUrl, 'photo_url'),
    'village': _optionalText(village, 'village'),
    'union': _optionalText(union, 'union'),
    'upazila': _requiredText(upazila, 'upazila'),
    'district': _requiredText(district, 'district'),
    'profession': _optionalText(profession, 'profession'),
  };
}

class DonorModel {
  static const fields = <String>{
    'name',
    'phone',
    'blood_group',
    'gender',
    'photo_url',
    'village',
    'union',
    'upazila',
    'district',
    'profession',
    'linked_user_id',
    'active',
    'last_donated_at',
    'total_donations',
    'created_at',
    'created_by',
    'updated_at',
    'updated_by',
  };

  final String id;
  final String name;
  final String phone;
  final String bloodGroup;
  final String? gender;
  final String? photoUrl;
  final String? village;
  final String? union;
  final String upazila;
  final String district;
  final String? profession;
  final String? linkedUserId;
  final bool active;
  final DateTime? lastDonatedAt;
  final int totalDonations;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;

  const DonorModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.bloodGroup,
    required this.gender,
    required this.photoUrl,
    required this.village,
    required this.union,
    required this.upazila,
    required this.district,
    required this.profession,
    required this.linkedUserId,
    required this.active,
    required this.lastDonatedAt,
    required this.totalDonations,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory DonorModel.fromMap(Map<String, dynamic> map, String id) {
    if (id.isEmpty || id.contains('/')) {
      throw const DonorDataException('Invalid donor document ID.');
    }
    final keys = map.keys.toSet();
    if (keys.difference(fields).isNotEmpty ||
        fields.difference(keys).isNotEmpty) {
      throw const DonorDataException('Donor has missing or unapproved fields.');
    }
    final total = map['total_donations'];
    if (total is! int || total < 0) {
      throw const DonorDataException(
        'total_donations must be a nonnegative integer.',
      );
    }
    return DonorModel(
      id: id,
      name: _requiredText(map['name'], 'name'),
      phone: _requiredText(map['phone'], 'phone'),
      bloodGroup: _requiredText(map['blood_group'], 'blood_group'),
      gender: _optionalText(map['gender'], 'gender'),
      photoUrl: _optionalHttpsUrl(map['photo_url'], 'photo_url'),
      village: _optionalText(map['village'], 'village'),
      union: _optionalText(map['union'], 'union'),
      upazila: _requiredText(map['upazila'], 'upazila'),
      district: _requiredText(map['district'], 'district'),
      profession: _optionalText(map['profession'], 'profession'),
      linkedUserId: _optionalId(map['linked_user_id'], 'linked_user_id'),
      active: _requiredBool(map['active'], 'active'),
      lastDonatedAt: _optionalTimestamp(
        map['last_donated_at'],
        'last_donated_at',
      ),
      totalDonations: total,
      createdAt: _requiredTimestamp(map['created_at'], 'created_at'),
      createdBy: _requiredId(map['created_by'], 'created_by'),
      updatedAt: _requiredTimestamp(map['updated_at'], 'updated_at'),
      updatedBy: _requiredId(map['updated_by'], 'updated_by'),
    );
  }
}

String _requiredText(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw DonorDataException('$field must be a non-empty string.');
  }
  return value.trim();
}

String? _optionalText(dynamic value, String field) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw DonorDataException('$field must be a non-empty string or null.');
  }
  return value.trim();
}

String _requiredId(dynamic value, String field) {
  final id = _requiredText(value, field);
  if (id.contains('/')) throw DonorDataException('$field is invalid.');
  return id;
}

String? _optionalId(dynamic value, String field) =>
    value == null ? null : _requiredId(value, field);

String? _optionalHttpsUrl(dynamic value, String field) {
  if (value == null) return null;
  if (value is! String || value.isEmpty || value.length > 2048) {
    throw DonorDataException('$field must be an HTTPS URL or null.');
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw DonorDataException('$field must be an HTTPS URL or null.');
  }
  return value;
}

bool _requiredBool(dynamic value, String field) {
  if (value is! bool) throw DonorDataException('$field must be a boolean.');
  return value;
}

DateTime _requiredTimestamp(dynamic value, String field) {
  if (value is! Timestamp) {
    throw DonorDataException('$field must be a Firestore Timestamp.');
  }
  return value.toDate();
}

DateTime? _optionalTimestamp(dynamic value, String field) =>
    value == null ? null : _requiredTimestamp(value, field);
