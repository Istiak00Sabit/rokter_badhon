import 'package:cloud_firestore/cloud_firestore.dart';

class DonationDataException implements Exception {
  final String message;
  const DonationDataException(this.message);
  @override
  String toString() => message;
}

class DonationModel {
  static const fields = <String>{
    'donor_id',
    'donor_name_snapshot',
    'blood_group_snapshot',
    'donation_date',
    'location',
    'hospital',
    'recipient_name',
    'recipient_contact',
    'recorded_by',
    'created_at',
    'updated_at',
  };
  final String id;
  final String donorId;
  final String donorNameSnapshot;
  final String bloodGroupSnapshot;
  final DateTime donationDate;
  final String? location;
  final String? hospital;
  final String? recipientName;
  final String? recipientContact;
  final String recordedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DonationModel({
    required this.id,
    required this.donorId,
    required this.donorNameSnapshot,
    required this.bloodGroupSnapshot,
    required this.donationDate,
    required this.location,
    required this.hospital,
    required this.recipientName,
    required this.recipientContact,
    required this.recordedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DonationModel.fromMap(Map<String, dynamic> map, String id) {
    _id(id, 'donation ID');
    final keys = map.keys.toSet();
    if (keys.difference(fields).isNotEmpty ||
        fields.difference(keys).isNotEmpty) {
      throw const DonationDataException(
        'Donation has missing or unapproved fields.',
      );
    }
    return DonationModel(
      id: id,
      donorId: _id(map['donor_id'], 'donor_id'),
      donorNameSnapshot: _text(
        map['donor_name_snapshot'],
        'donor_name_snapshot',
      ),
      bloodGroupSnapshot: _text(
        map['blood_group_snapshot'],
        'blood_group_snapshot',
      ),
      donationDate: _timestamp(map['donation_date'], 'donation_date'),
      location: _nullableText(map['location'], 'location'),
      hospital: _nullableText(map['hospital'], 'hospital'),
      recipientName: _nullableText(map['recipient_name'], 'recipient_name'),
      recipientContact: _nullableText(
        map['recipient_contact'],
        'recipient_contact',
      ),
      recordedBy: _id(map['recorded_by'], 'recorded_by'),
      createdAt: _timestamp(map['created_at'], 'created_at'),
      updatedAt: _nullableTimestamp(map['updated_at'], 'updated_at'),
    );
  }
}

String _text(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw DonationDataException('$field must be a non-empty string.');
  }
  return value.trim();
}

String? _nullableText(dynamic value, String field) =>
    value == null ? null : _text(value, field);
String _id(dynamic value, String field) {
  final result = _text(value, field);
  if (result.contains('/')) throw DonationDataException('$field is invalid.');
  return result;
}

DateTime _timestamp(dynamic value, String field) {
  if (value is! Timestamp) {
    throw DonationDataException('$field must be a Firestore Timestamp.');
  }
  return value.toDate();
}

DateTime? _nullableTimestamp(dynamic value, String field) =>
    value == null ? null : _timestamp(value, field);
