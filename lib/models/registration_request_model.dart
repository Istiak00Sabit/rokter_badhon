import 'package:cloud_firestore/cloud_firestore.dart';

enum RegistrationRequestStatus { pending, approved, rejected }

class RegistrationApplicantInput {
  static const fields = {'name', 'phone', 'email'};

  final String name;
  final String phone;
  final String email;

  const RegistrationApplicantInput({
    required this.name,
    required this.phone,
    required this.email,
  });

  factory RegistrationApplicantInput.fromMap(Map<String, dynamic> map) {
    if (map.keys.toSet().length != fields.length ||
        !map.keys.toSet().containsAll(fields)) {
      throw const FormatException(
        'Applicant input may contain only name, phone, and email.',
      );
    }
    return RegistrationApplicantInput(
      name: _requiredString(map, 'name'),
      phone: _requiredString(map, 'phone'),
      email: _requiredString(map, 'email'),
    );
  }
}

class RegistrationRequestModel {
  static const fields = {
    'auth_uid',
    'name',
    'phone',
    'email',
    'status',
    'requested_at',
    'approved_by',
    'approved_at',
    'rejected_by',
    'rejected_at',
    'linked_user_id',
  };

  final String authUid;
  final String name;
  final String phone;
  final String email;
  final RegistrationRequestStatus status;
  final DateTime requestedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? linkedUserId;

  const RegistrationRequestModel({
    required this.authUid,
    required this.name,
    required this.phone,
    required this.email,
    required this.status,
    required this.requestedAt,
    required this.approvedBy,
    required this.approvedAt,
    required this.rejectedBy,
    required this.rejectedAt,
    required this.linkedUserId,
  });

  factory RegistrationRequestModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final keys = map.keys.toSet();
    if (keys.length != fields.length || !keys.containsAll(fields)) {
      throw const FormatException(
        'RegistrationRequest has missing or unapproved fields.',
      );
    }
    final authUid = _requiredString(map, 'auth_uid');
    if (authUid != documentId) {
      throw const FormatException('auth_uid must match the document ID.');
    }
    return RegistrationRequestModel(
      authUid: authUid,
      name: _requiredString(map, 'name'),
      phone: _requiredString(map, 'phone'),
      email: _requiredString(map, 'email'),
      status: _status(map['status']),
      requestedAt: _requiredTimestamp(map, 'requested_at').toDate(),
      approvedBy: _nullableString(map, 'approved_by'),
      approvedAt: _nullableTimestamp(map, 'approved_at')?.toDate(),
      rejectedBy: _nullableString(map, 'rejected_by'),
      rejectedAt: _nullableTimestamp(map, 'rejected_at')?.toDate(),
      linkedUserId: _nullableString(map, 'linked_user_id'),
    );
  }

  static RegistrationRequestStatus _status(Object? value) {
    if (value is! String) {
      throw const FormatException('status must be a string.');
    }
    return switch (value) {
      'pending' => RegistrationRequestStatus.pending,
      'approved' => RegistrationRequestStatus.approved,
      'rejected' => RegistrationRequestStatus.rejected,
      _ => throw const FormatException('Unknown registration status.'),
    };
  }
}

class RegistrationRequestPayload {
  const RegistrationRequestPayload._();

  static Map<String, dynamic> create({
    required String authUid,
    required String authenticatedEmail,
    required RegistrationApplicantInput applicant,
  }) {
    if (authUid.isEmpty || authenticatedEmail.isEmpty) {
      throw const FormatException('Authenticated UID and email are required.');
    }
    if (applicant.email != authenticatedEmail) {
      throw const FormatException(
        'Applicant email must match the authenticated email.',
      );
    }
    return {
      'auth_uid': authUid,
      'name': applicant.name,
      'phone': applicant.phone,
      'email': authenticatedEmail,
      'status': 'pending',
      'requested_at': FieldValue.serverTimestamp(),
      'approved_by': null,
      'approved_at': null,
      'rejected_by': null,
      'rejected_at': null,
      'linked_user_id': null,
    };
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

Timestamp _requiredTimestamp(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Timestamp) throw FormatException('$key must be a Timestamp.');
  return value;
}

Timestamp? _nullableTimestamp(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value != null && value is! Timestamp) {
    throw FormatException('$key must be a Timestamp or null.');
  }
  return value as Timestamp?;
}
