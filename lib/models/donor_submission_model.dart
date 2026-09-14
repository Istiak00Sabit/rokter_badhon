import 'package:cloud_firestore/cloud_firestore.dart';

import 'donor_model.dart';

class DonorSubmissionModel {
  static const fields = <String>{
    'donor_payload',
    'committee_assignment_id',
    'submitted_by',
    'submitted_at',
    'status',
    'approved_by',
    'approved_at',
    'rejected_by',
    'rejected_at',
    'rejection_reason',
    'donor_id',
  };

  final String id;
  final DonorInput donor;
  final String? committeeAssignmentId;
  final String submittedBy;
  final DateTime submittedAt;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? donorId;

  const DonorSubmissionModel({
    required this.id,
    required this.donor,
    required this.committeeAssignmentId,
    required this.submittedBy,
    required this.submittedAt,
    required this.status,
    required this.approvedBy,
    required this.approvedAt,
    required this.rejectedBy,
    required this.rejectedAt,
    required this.rejectionReason,
    required this.donorId,
  });

  factory DonorSubmissionModel.fromMap(Map<String, dynamic> map, String id) {
    if (id.isEmpty ||
        id.contains('/') ||
        map.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(map.keys.toSet()).isNotEmpty) {
      throw const DonorDataException(
        'Donor submission has missing or unapproved fields.',
      );
    }
    final payload = map['donor_payload'];
    if (payload is! Map) {
      throw const DonorDataException('donor_payload must be a map.');
    }
    final values = Map<String, dynamic>.from(payload);
    const payloadFields = <String>{
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
    };
    if (values.keys.toSet().difference(payloadFields).isNotEmpty ||
        payloadFields.difference(values.keys.toSet()).isNotEmpty) {
      throw const DonorDataException(
        'donor_payload has missing or unapproved fields.',
      );
    }
    final status = _text(map['status'], 'status');
    if (!{'pending', 'approved', 'rejected'}.contains(status)) {
      throw const DonorDataException('Unknown donor submission status.');
    }
    final submittedAt = map['submitted_at'];
    if (submittedAt is! Timestamp) {
      throw const DonorDataException('submitted_at must be a Timestamp.');
    }
    return DonorSubmissionModel(
      id: id,
      donor: DonorInput(
        name: _text(values['name'], 'name'),
        phone: _text(values['phone'], 'phone'),
        bloodGroup: _text(values['blood_group'], 'blood_group'),
        gender: _nullable(values['gender'], 'gender'),
        photoUrl: _nullable(values['photo_url'], 'photo_url'),
        village: _nullable(values['village'], 'village'),
        union: _nullable(values['union'], 'union'),
        upazila: _text(values['upazila'], 'upazila'),
        district: _text(values['district'], 'district'),
        profession: _nullable(values['profession'], 'profession'),
      ),
      committeeAssignmentId: _nullable(
        map['committee_assignment_id'],
        'committee_assignment_id',
      ),
      submittedBy: _text(map['submitted_by'], 'submitted_by'),
      submittedAt: submittedAt.toDate(),
      status: status,
      approvedBy: _nullable(map['approved_by'], 'approved_by'),
      approvedAt: _nullableTimestamp(map['approved_at'], 'approved_at'),
      rejectedBy: _nullable(map['rejected_by'], 'rejected_by'),
      rejectedAt: _nullableTimestamp(map['rejected_at'], 'rejected_at'),
      rejectionReason: _nullable(map['rejection_reason'], 'rejection_reason'),
      donorId: _nullable(map['donor_id'], 'donor_id'),
    );
  }
}

String _text(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw DonorDataException('$field must be a non-empty string.');
  }
  return value.trim();
}

String? _nullable(dynamic value, String field) =>
    value == null ? null : _text(value, field);

DateTime? _nullableTimestamp(dynamic value, String field) {
  if (value == null) return null;
  if (value is! Timestamp) {
    throw DonorDataException('$field must be a Timestamp or null.');
  }
  return value.toDate();
}
