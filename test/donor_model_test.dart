import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/donor_model.dart';

final stamp = Timestamp.fromMillisecondsSinceEpoch(1700000000000);

Map<String, dynamic> validDonor({Map<String, dynamic> changes = const {}}) => {
  'name': 'Synthetic Donor',
  'phone': '01000000000',
  'blood_group': 'A+',
  'gender': null,
  'photo_url': 'https://example.test/donor.jpg',
  'village': null,
  'union': null,
  'upazila': 'Ghatail',
  'district': 'Tangail',
  'profession': null,
  'linked_user_id': null,
  'active': true,
  'last_donated_at': null,
  'total_donations': 0,
  'created_at': stamp,
  'created_by': 'actor-id',
  'updated_at': stamp,
  'updated_by': 'actor-id',
  ...changes,
};

void main() {
  test('strict donor parses the exact frozen schema', () {
    final donor = DonorModel.fromMap(validDonor(), 'donor-id');
    expect(donor.upazila, 'Ghatail');
    expect(donor.photoUrl, startsWith('https://'));
    expect(donor.lastDonatedAt, isNull);
    expect(donor.totalDonations, 0);
  });

  test('missing, extra, legacy, and malformed fields fail closed', () {
    final missing = validDonor()..remove('created_at');
    expect(
      () => DonorModel.fromMap(missing, 'id'),
      throwsA(isA<DonorDataException>()),
    );
    expect(
      () => DonorModel.fromMap(validDonor(changes: {'photo': ''}), 'id'),
      throwsA(isA<DonorDataException>()),
    );
    for (final changes in [
      {'created_at': '2025-01-01'},
      {'last_donated_at': '2025-01-01'},
      {'active': null},
      {'total_donations': -1},
      {'photo_url': 'http://example.test/photo.jpg'},
    ]) {
      expect(
        () => DonorModel.fromMap(validDonor(changes: changes), 'id'),
        throwsA(isA<DonorDataException>()),
      );
    }
  });

  test('new donor input contains profile fields only', () {
    final fields = const DonorInput(
      name: ' Name ',
      phone: ' Phone ',
      bloodGroup: 'A+',
      upazila: 'Ghatail',
      district: 'Tangail',
    ).profileFields();
    expect(fields.keys, DonorModel.fields.take(10));
    expect(fields['name'], 'Name');
    expect(fields, isNot(contains('last_donated_at')));
    expect(fields, isNot(contains('total_donations')));
  });

  test(
    'service uses active-only queries and exact server-owned initial state',
    () {
      final source = File('lib/services/donor_service.dart').readAsStringSync();
      expect(source, contains(".where('active', isEqualTo: true)"));
      expect(source, contains(".orderBy('name')"));
      expect(source, contains("'last_donated_at': null"));
      expect(source, contains("'total_donations': 0"));
      expect(source, contains('FieldValue.serverTimestamp()'));
      expect(source, isNot(contains("'photo':")));
      expect(source, isNot(contains("'upazilla':")));
      expect(source, isNot(contains('DateTime.now()')));
    },
  );
}
