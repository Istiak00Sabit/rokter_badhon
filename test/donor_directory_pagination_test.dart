import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/controllers/auth_controller.dart';
import 'package:rokter_badhon/controllers/donor_controller.dart';
import 'package:rokter_badhon/models/donor_model.dart';
import 'package:rokter_badhon/models/user_model.dart';
import 'package:rokter_badhon/services/donor_service.dart';

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Cursor is opaque to the controller and never accessed through Firestore.
// ignore: subtype_of_sealed_class
class _Cursor implements DocumentSnapshot<Map<String, dynamic>> {
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
    bloodGroup: 'A+',
    profession: null,
    address: null,
    photoUrl: null,
    accessRole: 'member',
    active: true,
    loginEnabled: true,
    preferredLanguage: null,
    createdAt: DateTime.utc(2026, 10, 11),
    createdBy: null,
    updatedAt: DateTime.utc(2026, 10, 11),
    updatedBy: null,
  ));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DonorModel _donor(String id, String group) => DonorModel(
  id: id,
  name: 'Synthetic $id',
  phone: '01700000000',
  bloodGroup: group,
  gender: null,
  photoUrl: null,
  village: null,
  union: null,
  upazila: 'Ghatail',
  district: 'Tangail',
  profession: null,
  linkedUserId: null,
  active: true,
  lastDonatedAt: null,
  totalDonations: 0,
  createdAt: DateTime.utc(2026, 10, 11),
  createdBy: 'test',
  updatedAt: DateTime.utc(2026, 10, 11),
  updatedBy: 'test',
);

class _PagedDonors extends DonorService {
  _PagedDonors() : super(firestore: _UnusedFirestore());
  final cursor = _Cursor();
  final requests = <String>[];
  bool failOnce = true;

  @override
  Future<ActiveDonorPage> getActiveDonorsPage({
    String? bloodGroup,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    expect(pageSize, 30);
    requests.add('${bloodGroup ?? 'all'}:${after == null ? 'first' : 'next'}');
    if (bloodGroup != null) {
      expect(bloodGroup, 'O+');
      return ActiveDonorPage(
        items: [_donor('o1', 'O+')],
        cursor: null,
        hasMore: false,
      );
    }
    if (after == null) {
      return ActiveDonorPage(
        items: [_donor('a1', 'A+'), _donor('a2', 'A+')],
        cursor: cursor,
        hasMore: true,
      );
    }
    expect(identical(after, cursor), true);
    if (failOnce) {
      failOnce = false;
      throw const DonorServiceException('network_unavailable');
    }
    return ActiveDonorPage(
      items: [_donor('a2', 'A+'), _donor('a3', 'A+')],
      cursor: null,
      hasMore: false,
    );
  }
}

class _RaceDonors extends DonorService {
  _RaceDonors() : super(firestore: _UnusedFirestore());
  final pending = Completer<ActiveDonorPage>();

  @override
  Future<ActiveDonorPage> getActiveDonorsPage({
    String? bloodGroup,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) {
    if (bloodGroup == null) return pending.future;
    return Future.value(ActiveDonorPage(
      items: [_donor('o1', 'O+')],
      cursor: null,
      hasMore: false,
    ));
  }
}

void main() {
  test('later donor page failure keeps existing records and retry never duplicates IDs', () async {
    final service = _PagedDonors();
    final controller = DonorController(
      donorService: service, authController: _TestAuth(),
    );
    await controller.loadDonors();
    expect(controller.donors.map((e) => e.id), ['a1', 'a2']);
    expect(controller.hasMoreDonors.value, true);

    await controller.loadMoreDonors();
    expect(controller.pageErrorCode.value, 'network_unavailable');
    expect(controller.donors.map((e) => e.id), ['a1', 'a2']);
    expect(controller.hasMoreDonors.value, true);

    await controller.loadMoreDonors();
    expect(controller.pageErrorCode.value, isEmpty);
    expect(controller.donors.map((e) => e.id), ['a1', 'a2', 'a3']);
    expect(controller.hasMoreDonors.value, false);
    await controller.loadMoreDonors();
    expect(service.requests, ['all:first', 'all:next', 'all:next']);

    await controller.setDirectoryBloodGroup('O+');
    expect(controller.donors.map((e) => e.id), ['o1']);
    expect(controller.hasMoreDonors.value, false);
    expect(service.requests.last, 'O+:first');
    controller.onClose();
  });

  test('changing group before earlier query completes discards stale directory results',
      () async {
    final service = _RaceDonors();
    final controller = DonorController(
      donorService: service, authController: _TestAuth(),
    );
    final old = controller.loadDonors();
    await controller.setDirectoryBloodGroup('O+');
    expect(controller.donors.map((e) => e.id), ['o1']);
    service.pending.complete(ActiveDonorPage(
      items: [_donor('stale', 'A+')],
      cursor: null,
      hasMore: false,
    ));
    await old;
    expect(controller.donors.map((e) => e.id), ['o1']);
    expect(controller.directoryBloodGroup.value, 'O+');
    controller.onClose();
  });
}
