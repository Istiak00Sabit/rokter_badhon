import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/donor_submission_model.dart';
import 'package:rokter_badhon/models/donor_model.dart';

Map<String, dynamic> pending() => {
  'donor_payload': {
    'name': 'Donor',
    'phone': '01700000000',
    'blood_group': 'O+',
    'gender': null,
    'photo_url': null,
    'village': 'Village',
    'union': null,
    'upazila': 'Ghatail',
    'district': 'Tangail',
    'profession': null,
  },
  'committee_assignment_id': 'assignment-1',
  'submitted_by': 'user-1',
  'submitted_at': Timestamp.fromMillisecondsSinceEpoch(1),
  'status': 'pending',
  'approved_by': null,
  'approved_at': null,
  'rejected_by': null,
  'rejected_at': null,
  'rejection_reason': null,
  'donor_id': null,
};

void main() {
  test('pending donor submission parses exact review and payload schema', () {
    final submission = DonorSubmissionModel.fromMap(pending(), 'submission-1');
    expect(submission.status, 'pending');
    expect(submission.donor.bloodGroup, 'O+');
    expect(submission.committeeAssignmentId, 'assignment-1');
  });

  test('submission rejects extra fields and forged status', () {
    expect(
      () => DonorSubmissionModel.fromMap({...pending(), 'active': true}, 'x'),
      throwsA(isA<DonorDataException>()),
    );
    expect(
      () =>
          DonorSubmissionModel.fromMap({...pending(), 'status': 'active'}, 'x'),
      throwsA(isA<DonorDataException>()),
    );
    final extraPayload = Map<String, dynamic>.from(pending());
    extraPayload['donor_payload'] = {
      ...pending()['donor_payload'] as Map<String, dynamic>,
      'approved_by': 'x',
    };
    expect(
      () => DonorSubmissionModel.fromMap(extraPayload, 'x'),
      throwsA(isA<DonorDataException>()),
    );
  });
}
