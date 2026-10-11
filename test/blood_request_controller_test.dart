import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/controllers/auth_controller.dart';
import 'package:rokter_badhon/controllers/blood_request_controller.dart';
import 'package:rokter_badhon/models/blood_request_model.dart';
import 'package:rokter_badhon/models/user_model.dart';
import 'package:rokter_badhon/services/blood_request_service.dart';

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuth implements AuthController {
  @override
  final Rx<UserModel?> currentUser = Rx<UserModel?>(UserModel(
    id: 'synthetic-user',
    name: 'Synthetic Member',
    phone: '01700000000',
    email: null,
    bloodGroup: 'O+',
    profession: null,
    address: null,
    photoUrl: null,
    accessRole: 'member',
    active: true,
    loginEnabled: true,
    preferredLanguage: null,
    createdAt: DateTime.utc(2026, 10, 10),
    createdBy: null,
    updatedAt: DateTime.utc(2026, 10, 10),
    updatedBy: null,
  ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RequestService extends BloodRequestService {
  _RequestService() : super(firestore: _UnusedFirestore());

  int createCalls = 0;
  int loadCalls = 0;
  Completer<String> write = Completer<String>();

  @override
  Future<String> create(BloodRequestInput input, String actorId) {
    expect(actorId, 'synthetic-user');
    createCalls++;
    return write.future;
  }

  @override
  Future<BloodRequestPage> getByStatusPage(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    expect(status, 'active');
    expect(after, isNull);
    loadCalls++;
    return const BloodRequestPage(
      items: <BloodRequestModel>[], cursor: null, hasMore: false,
    );
  }
}

class _FakeCursor implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  _FakeCursor(this.id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BloodRequestModel _request(String id, String status, int minute) {
  final date = DateTime.utc(2026, 10, 10, 0, minute);
  return BloodRequestModel(
    id: id,
    bloodGroup: 'O+',
    patientName: null,
    hospital: 'Synthetic Hospital',
    location: 'Ghatail',
    contactName: 'Test Person',
    contactPhone: '01700000000',
    requiredAt: null,
    status: status,
    createdBy: 'synthetic-user',
    createdAt: date,
    fulfilledBy: status == 'fulfilled' ? 'synthetic-leader' : null,
    fulfilledAt: status == 'fulfilled' ? date : null,
  );
}

class _PagedRequestService extends BloodRequestService {
  _PagedRequestService() : super(firestore: _UnusedFirestore());

  bool failActivePageOnce = true;
  final calls = <String>[];

  @override
  Future<BloodRequestPage> getByStatusPage(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    calls.add(status);
    if (status != 'active') {
      throw StateError('Member must not fetch terminal requests.');
    }
    if (after == null) {
      return BloodRequestPage(
        items: [_request('request-new', 'active', 30)],
        cursor: _FakeCursor('request-new'), hasMore: true,
      );
    }
    if (failActivePageOnce) {
      failActivePageOnce = false;
      throw const BloodRequestServiceException('network_unavailable');
    }
    return BloodRequestPage(
      items: [_request('request-old', 'active', 10)],
      cursor: _FakeCursor('request-old'), hasMore: false,
    );
  }
}

void main() {
  const input = BloodRequestInput(
    bloodGroup: 'O+',
    hospital: 'Synthetic Hospital',
    location: 'Ghatail',
    contactName: 'Synthetic Contact',
    contactPhone: '01700000000',
  );

  test('only one emergency request can be sent while Firestore write is pending', () async {
    final service = _RequestService();
    final controller = BloodRequestController(
      service: service,
      auth: _TestAuth(),
    );

    final first = controller.create(input);
    expect(controller.isSubmitting.value, true);
    expect(service.createCalls, 1);

    expect(await controller.create(input), false);
    expect(service.createCalls, 1);

    service.write.complete('created-request-id');
    expect(await first, true);
    expect(controller.isSubmitting.value, false);
    expect(service.loadCalls, 1);
    expect(controller.errorCode.value, isEmpty);
  });

  test('write failure stops loading and displays the safe error code', () async {
    final service = _RequestService();
    final controller = BloodRequestController(
      service: service,
      auth: _TestAuth(),
    );
    final first = controller.create(input);
    service.write.completeError(
      const BloodRequestServiceException('network_unavailable'),
    );
    expect(await first, false);
    expect(service.createCalls, 1);
    expect(service.loadCalls, 0);
    expect(controller.isSubmitting.value, false);
    expect(controller.errorCode.value, 'network_unavailable');
  });
  test('active page failure preserves visible items and retry reads next cursor', () async {
    final service = _PagedRequestService();
    final controller = BloodRequestController(
      service: service, auth: _TestAuth(),
    );
    await controller.load();
    expect(controller.active.map((value) => value.id), ['request-new']);
    expect(controller.activeHasMore.value, isTrue);
    expect(controller.terminal, isEmpty);

    await controller.loadMoreActive();
    expect(controller.activePageErrorCode.value, 'network_unavailable');
    expect(controller.active.map((value) => value.id), ['request-new']);
    expect(controller.activeHasMore.value, isTrue);

    await controller.loadMoreActive();
    expect(controller.activePageErrorCode.value, isEmpty);
    expect(controller.active.map((value) => value.id),
        ['request-new', 'request-old']);
    expect(controller.activeHasMore.value, isFalse);
    expect(service.calls, ['active', 'active', 'active']);
  });

}
