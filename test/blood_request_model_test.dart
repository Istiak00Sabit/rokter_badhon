import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/blood_request_model.dart';

Map<String, dynamic> request([Map<String, dynamic> changes = const {}]) => {
  'blood_group': 'A+',
  'patient_name': null,
  'hospital': 'Hospital',
  'location': 'Ghatail',
  'contact_name': 'Contact',
  'contact_phone': '01000',
  'required_at': null,
  'status': 'active',
  'created_by': 'user-1',
  'created_at': Timestamp(1, 0),
  'fulfilled_by': null,
  'fulfilled_at': null,
  ...changes,
};

void main() {
  test('strict active and fulfilled requests parse exact Timestamp schema', () {
    expect(BloodRequestModel.fromMap(request(), 'request-1').status, 'active');
    expect(
      BloodRequestModel.fromMap(
        request({
          'status': 'fulfilled',
          'fulfilled_by': 'user-2',
          'fulfilled_at': Timestamp(2, 0),
        }),
        'request-1',
      ).status,
      'fulfilled',
    );
    expect(
      () => BloodRequestModel.fromMap(request({'legacy': true}), 'request-1'),
      throwsA(isA<BloodRequestDataException>()),
    );
    expect(
      () => BloodRequestModel.fromMap(
        request({'created_at': 'today'}),
        'request-1',
      ),
      throwsA(isA<BloodRequestDataException>()),
    );
  });

  test('terminal metadata and statuses fail closed', () {
    expect(
      () => BloodRequestModel.fromMap(
        request({'status': 'fulfilled'}),
        'request-1',
      ),
      throwsA(isA<BloodRequestDataException>()),
    );
    expect(
      () => BloodRequestModel.fromMap(
        request({'status': 'cancelled', 'fulfilled_by': 'user-2'}),
        'request-1',
      ),
      throwsA(isA<BloodRequestDataException>()),
    );
    expect(
      () => BloodRequestModel.fromMap(request({'status': 'open'}), 'request-1'),
      throwsA(isA<BloodRequestDataException>()),
    );
  });

  test('client create is exact and service queries one authorized status', () {
    final map = const BloodRequestInput(
      bloodGroup: 'A+',
      hospital: 'H',
      location: 'L',
      contactName: 'C',
      contactPhone: 'P',
    ).createMap('user-1');
    expect(map.keys.toSet(), BloodRequestModel.fields);
    expect(map['status'], 'active');
    expect(map['created_at'], isA<FieldValue>());
    expect(map['fulfilled_by'], isNull);
    final source = File(
      'lib/services/blood_request_service.dart',
    ).readAsStringSync();
    expect(source, contains("where('status', isEqualTo: status)"));
    expect(source, isNot(contains("collection('requests')")));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
  });
}
