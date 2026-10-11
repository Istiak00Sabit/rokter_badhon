import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/donor_model.dart';
import 'package:rokter_badhon/services/donor_service.dart';

void main() {
  test('normalizes BD phone before reservation and pending submission', () {
    for (final number in [
      '01712345678', '+8801712345678', '8801712345678',
      '+880 1712-345678', '০১৭১২৩৪৫৬৭৮',
    ]) {
      expect(DonorService.canonicalDonorPhone(number), '01712345678');
    }
  });

  test('invalid or partial phone IDs cannot create a reservation', () {
    for (final number in ['', '017', '01212345678', '+991712345678']) {
      expect(() => DonorService.canonicalDonorPhone(number),
          throwsA(isA<DonorDataException>()));
    }
  });

  test('approval has one atomic key, donor and submission transaction', () {
    final service = File('lib/services/donor_service.dart').readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();
    expect(service, contains("collection('donor_phone_keys').doc(phone)"));
    expect(service, contains("collection('system_config').doc('donor_phone_registry')"));
    expect(service, contains("registry.data()?['ready'] != true"));
    expect(service, contains('final existingKey = await transaction.get(keyRef)'));
    expect(service, contains('transaction.set(donorRef, {'));
    expect(service, contains('transaction.update(submissionRef, {'));
    expect(service, contains('transaction.set(keyRef, {'));
    expect(service, contains("'donor_phone_change_locked'"));
    expect(rules, contains('function donorRegistryReady()'));
    expect(rules, contains('match /donor_phone_keys/{phone}'));
    expect(rules, contains('getAfter(donorPhoneKeyPath(d.phone))'));
    expect(rules, contains('request.resource.data.phone == resource.data.phone'));
  });
}
