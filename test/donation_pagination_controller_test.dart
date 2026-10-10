import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/controllers/donation_controller.dart';
import 'package:rokter_badhon/models/donation_model.dart';
import 'package:rokter_badhon/services/donation_service.dart';

class _UnneededFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only structural fake for a Firestore cursor; no Firebase reads occur.
// ignore: subtype_of_sealed_class
class _Cursor implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DonationModel _entry(String id) => DonationModel(
  id: id,
  donorId: 'donor-$id',
  donorNameSnapshot: 'Synthetic Donor $id',
  bloodGroupSnapshot: 'A+',
  donationDate: DateTime.utc(2026, 10, 10),
  location: null,
  hospital: null,
  recipientName: null,
  recipientContact: null,
  recordedBy: 'operator',
  createdAt: DateTime.utc(2026, 10, 10),
  updatedAt: null,
);

class _PagedDonations extends DonationService {
  _PagedDonations() : super(firestore: _UnneededFirestore());

  final firstCursor = _Cursor();
  var firstReads = 0;
  var nextReads = 0;
  var failFirst = false;
  var failNext = false;

  @override
  Future<DonationPage> getHistoryPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    expect(pageSize, 30);
    if (after == null) {
      firstReads++;
      if (failFirst) {
        throw const DonationServiceException('permission_denied');
      }
      return DonationPage(
        items: [_entry('1'), _entry('2')],
        cursor: firstCursor,
        hasMore: true,
      );
    }
    expect(identical(after, firstCursor), isTrue);
    nextReads++;
    if (failNext) {
      failNext = false;
      throw const DonationServiceException('network_unavailable');
    }
    return DonationPage(items: [_entry('3')], cursor: null, hasMore: false);
  }
}

void main() {
  test('donation history first page and retryable pagination keep existing records', () async {
    final service = _PagedDonations();
    final controller = DonationController(service: service);

    await controller.loadHistory();
    expect(service.firstReads, 1);
    expect(controller.donations.map((x) => x.id).toList(), ['1', '2']);
    expect(controller.hasMore.value, true);
    expect(controller.isLoading.value, false);

    service.failNext = true;
    await controller.loadMore();
    expect(controller.pageErrorCode.value, 'network_unavailable');
    expect(controller.donations.length, 2);
    expect(controller.hasMore.value, true);
    expect(controller.isLoadingMore.value, false);

    await controller.loadMore();
    expect(controller.pageErrorCode.value, isEmpty);
    expect(controller.donations.map((x) => x.id).toList(), ['1', '2', '3']);
    expect(controller.hasMore.value, false);
    expect(service.nextReads, 2);

    // Do not send a query past the last page.
    await controller.loadMore();
    expect(service.nextReads, 2);

    await controller.loadHistory();
    expect(service.firstReads, 2);
    expect(controller.donations.map((x) => x.id).toList(), ['1', '2']);
    expect(controller.hasMore.value, true);
  });

  test('permission-denied first page never masquerades as empty history', () async {
    final service = _PagedDonations()..failFirst = true;
    final controller = DonationController(service: service);

    await controller.loadHistory();
    expect(service.firstReads, 1);
    expect(controller.errorCode.value, 'permission_denied');
    expect(controller.donations, isEmpty);
    expect(controller.isLoading.value, false);
    expect(controller.hasMore.value, false);

    service.failFirst = false;
    await controller.loadHistory();
    expect(service.firstReads, 2);
    expect(controller.errorCode.value, isEmpty);
    expect(controller.donations, hasLength(2));
  });
}
