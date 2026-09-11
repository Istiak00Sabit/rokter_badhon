import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequestDataException implements Exception {
  final String message;
  const BloodRequestDataException(this.message);
}

class BloodRequestInput {
  final String bloodGroup;
  final String? patientName;
  final String hospital;
  final String location;
  final String contactName;
  final String contactPhone;
  final DateTime? requiredAt;
  const BloodRequestInput({
    required this.bloodGroup,
    this.patientName,
    required this.hospital,
    required this.location,
    required this.contactName,
    required this.contactPhone,
    this.requiredAt,
  });

  Map<String, dynamic> createMap(String actorId) => {
    'blood_group': _text(bloodGroup, 'blood_group'),
    'patient_name': _nullableText(patientName, 'patient_name'),
    'hospital': _text(hospital, 'hospital'),
    'location': _text(location, 'location'),
    'contact_name': _text(contactName, 'contact_name'),
    'contact_phone': _text(contactPhone, 'contact_phone'),
    'required_at': requiredAt == null ? null : Timestamp.fromDate(requiredAt!),
    'status': 'active',
    'created_by': _id(actorId, 'created_by'),
    'created_at': FieldValue.serverTimestamp(),
    'fulfilled_by': null,
    'fulfilled_at': null,
  };
}

class BloodRequestModel {
  static const fields = <String>{
    'blood_group',
    'patient_name',
    'hospital',
    'location',
    'contact_name',
    'contact_phone',
    'required_at',
    'status',
    'created_by',
    'created_at',
    'fulfilled_by',
    'fulfilled_at',
  };
  final String id;
  final String bloodGroup;
  final String? patientName;
  final String hospital;
  final String location;
  final String contactName;
  final String contactPhone;
  final DateTime? requiredAt;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final String? fulfilledBy;
  final DateTime? fulfilledAt;

  const BloodRequestModel({
    required this.id,
    required this.bloodGroup,
    required this.patientName,
    required this.hospital,
    required this.location,
    required this.contactName,
    required this.contactPhone,
    required this.requiredAt,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.fulfilledBy,
    required this.fulfilledAt,
  });

  factory BloodRequestModel.fromMap(Map<String, dynamic> map, String id) {
    _id(id, 'request ID');
    final keys = map.keys.toSet();
    if (keys.difference(fields).isNotEmpty ||
        fields.difference(keys).isNotEmpty) {
      throw const BloodRequestDataException(
        'BloodRequest has missing or unapproved fields.',
      );
    }
    final status = _text(map['status'], 'status');
    if (!{'active', 'fulfilled', 'cancelled'}.contains(status)) {
      throw const BloodRequestDataException('Unknown request status.');
    }
    final fulfilledBy = _nullableId(map['fulfilled_by'], 'fulfilled_by');
    final fulfilledAt = _nullableTimestamp(map['fulfilled_at'], 'fulfilled_at');
    if ((status == 'fulfilled' &&
            (fulfilledBy == null || fulfilledAt == null)) ||
        (status != 'fulfilled' &&
            (fulfilledBy != null || fulfilledAt != null))) {
      throw const BloodRequestDataException(
        'Request fulfillment metadata is inconsistent.',
      );
    }
    return BloodRequestModel(
      id: id,
      bloodGroup: _text(map['blood_group'], 'blood_group'),
      patientName: _nullableText(map['patient_name'], 'patient_name'),
      hospital: _text(map['hospital'], 'hospital'),
      location: _text(map['location'], 'location'),
      contactName: _text(map['contact_name'], 'contact_name'),
      contactPhone: _text(map['contact_phone'], 'contact_phone'),
      requiredAt: _nullableTimestamp(map['required_at'], 'required_at'),
      status: status,
      createdBy: _id(map['created_by'], 'created_by'),
      createdAt: _timestamp(map['created_at'], 'created_at'),
      fulfilledBy: fulfilledBy,
      fulfilledAt: fulfilledAt,
    );
  }
}

String _text(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw BloodRequestDataException('$field must be non-empty.');
  }
  return value.trim();
}

String? _nullableText(dynamic value, String field) =>
    value == null ? null : _text(value, field);
String _id(dynamic input, String field) {
  final value = _text(input, field);
  if (value.contains('/')) {
    throw BloodRequestDataException('$field is invalid.');
  }
  return value;
}

String? _nullableId(dynamic value, String field) =>
    value == null ? null : _id(value, field);
DateTime _timestamp(dynamic value, String field) {
  if (value is! Timestamp) {
    throw BloodRequestDataException('$field must be a Firestore Timestamp.');
  }
  return value.toDate();
}

DateTime? _nullableTimestamp(dynamic value, String field) =>
    value == null ? null : _timestamp(value, field);
