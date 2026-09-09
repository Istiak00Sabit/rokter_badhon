import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/registration_request_model.dart';

Map<String, dynamic> validRequest({Map<String, dynamic> changes = const {}}) => {
  'auth_uid': 'auth-uid',
  'name': 'Applicant',
  'phone': '00000000000',
  'email': 'applicant@example.test',
  'status': 'pending',
  'requested_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
  'approved_by': null,
  'approved_at': null,
  'rejected_by': null,
  'rejected_at': null,
  'linked_user_id': null,
  ...changes,
};

void main() {
  test('RegistrationRequest strictly parses the exact v1.2.1 schema', () {
    final request = RegistrationRequestModel.fromMap(
      validRequest(),
      'auth-uid',
    );
    expect(request.status, RegistrationRequestStatus.pending);

    for (final malformed in [
      validRequest(changes: {'status': 'waiting'}),
      validRequest(changes: {'requested_at': DateTime(2026)}),
      validRequest(changes: {'approved_by': false}),
      validRequest(changes: {'linked_user_id': 7}),
      validRequest(changes: {'access_role': 'leader'}),
    ]) {
      expect(
        () => RegistrationRequestModel.fromMap(malformed, 'auth-uid'),
        throwsFormatException,
      );
    }
    expect(
      () => RegistrationRequestModel.fromMap(validRequest(), 'other-uid'),
      throwsFormatException,
    );
  });

  test('applicant input cannot contain security or decision fields', () {
    for (final field in [
      'access_role',
      'position',
      'committee_term',
      'login_enabled',
      'active',
      'linked_user_id',
      'status',
      'approved_by',
      'rejected_at',
    ]) {
      expect(
        () => RegistrationApplicantInput.fromMap({
          'name': 'Applicant',
          'phone': '00000000000',
          'email': 'applicant@example.test',
          field: null,
        }),
        throwsFormatException,
      );
    }
  });

  test('decision metadata must exactly match request status', () {
    for (final malformed in [
      validRequest(changes: {'approved_by': 'operator'}),
      validRequest(changes: {'status': 'approved'}),
      validRequest(changes: {
        'status': 'rejected',
        'rejected_by': 'operator',
        'rejected_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
        'linked_user_id': 'user-id',
      }),
    ]) {
      expect(
        () => RegistrationRequestModel.fromMap(malformed, 'auth-uid'),
        throwsFormatException,
      );
    }

    expect(
      RegistrationRequestModel.fromMap(
        validRequest(changes: {
          'status': 'approved',
          'approved_by': 'operator',
          'approved_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
          'linked_user_id': 'user-id',
        }),
        'auth-uid',
      ).status,
      RegistrationRequestStatus.approved,
    );
  });

  test('registration creation payload binds UID, email, pending, and null decisions', () {
    final payload = RegistrationRequestPayload.create(
      authUid: 'auth-uid',
      authenticatedEmail: 'applicant@example.test',
      applicant: const RegistrationApplicantInput(
        name: 'Applicant',
        phone: '00000000000',
        email: 'applicant@example.test',
      ),
    );
    expect(payload.keys.toSet(), RegistrationRequestModel.fields);
    expect(payload['auth_uid'], 'auth-uid');
    expect(payload['email'], 'applicant@example.test');
    expect(payload['status'], 'pending');
    for (final key in [
      'approved_by',
      'approved_at',
      'rejected_by',
      'rejected_at',
      'linked_user_id',
    ]) {
      expect(payload[key], isNull);
    }
    expect(
      () => RegistrationRequestPayload.create(
        authUid: 'auth-uid',
        authenticatedEmail: 'firebase@example.test',
        applicant: const RegistrationApplicantInput(
          name: 'Applicant',
          phone: '0',
          email: 'different@example.test',
        ),
      ),
      throwsFormatException,
    );
  });
}
