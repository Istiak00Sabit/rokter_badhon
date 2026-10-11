import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/donor_model.dart';
import 'package:rokter_badhon/services/donor_service.dart';

void main() {
  test('exact phone input canonicalizes BD domestic and international forms', () {
    for (final value in [
      '01712345678',
      '+8801712345678',
      '8801712345678',
      '+880 1712-345678',
    ]) {
      expect(DonorService.normalizeSearchPhone(value), '01712345678');
    }
    expect(DonorService.normalizeSearchPhone('সৈকত'), isNull);
    expect(DonorService.normalizeSearchPhone('Rahim'), isNull);
  });

  test('partial or invalid numeric strings never masquerade as complete search', () {
    for (final value in ['017', '1234567890', '+991712345678']) {
      expect(() => DonorService.normalizeSearchPhone(value),
          throwsA(isA<DonorDataException>()));
    }
  });

  test('indexed donor lookup remains status-scoped and cursor bounded', () {
    final service = File('lib/services/donor_service.dart').readAsStringSync();
    final controller = File('lib/controllers/donor_controller.dart').readAsStringSync();
    final screen = File('lib/views/donor_list_screen.dart').readAsStringSync();
    expect(service, contains('searchActiveDonorsPage('));
    expect(service, contains("where('active', isEqualTo: true)"));
    expect(service, contains("where('phone', isEqualTo: phone)"));
    expect(service, contains('startAt([term]).endAt('));
    expect(service, contains('startAfterDocument(after)'));
    expect(service, contains('query.limit(pageSize + 1)'));
    expect(controller, contains('indexedSearchTerm'));
    expect(controller, contains('search: term'));
    expect(screen, contains('onSubmitted: controller.searchDirectory'));
    expect(screen, contains("donor_indexed_search_active"));
  });
}
