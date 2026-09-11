import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/donation_model.dart';

Map<String, dynamic> donation([Map<String, dynamic> changes = const {}]) => {
  'donor_id': 'donor-1',
  'donor_name_snapshot': 'Donor One',
  'blood_group_snapshot': 'A+',
  'donation_date': Timestamp(10, 0),
  'location': null,
  'hospital': null,
  'recipient_name': null,
  'recipient_contact': null,
  'recorded_by': 'user-1',
  'created_at': Timestamp(11, 0),
  'updated_at': null,
  ...changes,
};

void main() {
  test('Donation parses only the canonical exact Timestamp schema', () {
    final value = DonationModel.fromMap(donation(), 'donation-1');
    expect(value.donorNameSnapshot, 'Donor One');
    expect(value.donationDate, Timestamp(10, 0).toDate());
    expect(
      () =>
          DonationModel.fromMap(donation({'date': '2026-01-01'}), 'donation-1'),
      throwsA(isA<DonationDataException>()),
    );
    expect(
      () => DonationModel.fromMap(
        donation({'donation_date': '2026-01-01'}),
        'donation-1',
      ),
      throwsA(isA<DonationDataException>()),
    );
  });

  test(
    'Donation rejects missing, malformed and invalid IDs without defaults',
    () {
      final missing = donation()..remove('recipient_contact');
      expect(
        () => DonationModel.fromMap(missing, 'donation-1'),
        throwsA(isA<DonationDataException>()),
      );
      expect(
        () => DonationModel.fromMap(
          donation({'recorded_by': 'bad/id'}),
          'donation-1',
        ),
        throwsA(isA<DonationDataException>()),
      );
      expect(
        () => DonationModel.fromMap(donation({'location': ''}), 'donation-1'),
        throwsA(isA<DonationDataException>()),
      );
    },
  );

  test('history and dashboard use canonical read-only Timestamp queries', () {
    final history = File(
      'lib/services/donation_service.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/services/dashboard_service.dart',
    ).readAsStringSync();
    expect(history, contains("orderBy('donation_date', descending: true)"));
    expect(history, isNot(contains('.add(')));
    expect(dashboard, contains("'donation_date'"));
    expect(dashboard, contains('Timestamp.fromDate(firstDayUtc)'));
    expect(dashboard, contains('Timestamp.fromDate(nextMonthUtc)'));
    expect(dashboard, isNot(contains("where('date'")));
    expect(dashboard, isNot(contains('toIso8601String')));
  });
}
