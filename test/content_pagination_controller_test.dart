import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/controllers/auth_controller.dart';
import 'package:rokter_badhon/controllers/event_controller.dart';
import 'package:rokter_badhon/controllers/notice_controller.dart';
import 'package:rokter_badhon/models/event_model.dart';
import 'package:rokter_badhon/models/notice_model.dart';
import 'package:rokter_badhon/models/user_model.dart';
import 'package:rokter_badhon/services/event_service.dart';
import 'package:rokter_badhon/services/notice_service.dart';

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only cursor: no Firestore method on this object is ever called.
// ignore: subtype_of_sealed_class
class _Cursor implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  _Cursor(this.id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuth implements AuthController {
  @override
  final Rx<UserModel?> currentUser;

  _TestAuth(String role)
    : currentUser = Rx<UserModel?>(UserModel(
        id: 'person-own',
        name: 'Synthetic Member',
        phone: '01700000000',
        email: null,
        bloodGroup: 'A+',
        profession: null,
        address: null,
        photoUrl: null,
        accessRole: role,
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

NoticeModel _notice(String id, String status, int minute) => NoticeModel(
  id: id,
  title: 'Synthetic notice',
  body: 'Synthetic body',
  important: false,
  status: status,
  createdBy: 'person-own',
  createdAt: DateTime.utc(2026, 10, 10, 0, minute),
  updatedBy: null,
  updatedAt: null,
);

EventModel _event(String id, bool active, int minute) => EventModel(
  id: id,
  title: 'Synthetic event',
  description: null,
  eventType: 'meeting',
  eventDate: DateTime.utc(2026, 10, 10, 0, minute),
  location: null,
  coverImageUrl: null,
  active: active,
  createdAt: DateTime.utc(2026, 10, 10),
  createdBy: 'person-own',
  updatedAt: null,
  updatedBy: null,
);

class _PagedNotices extends NoticeService {
  _PagedNotices() : super(firestore: _UnusedFirestore());
  final calls = <String>[];
  bool failPublishedOnce = true;
  bool failArchivedOnce = true;

  @override
  Future<NoticePage> getByStatusPage(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    expect(pageSize, 30);
    calls.add('$status:${after == null ? 'first' : 'next'}');
    if (after == null) {
      final id = '$status-new';
      return NoticePage(
        items: [_notice(id, status, status == 'draft' ? 50 : 40)],
        cursor: _Cursor(id),
        hasMore: true,
      );
    }
    if (status == 'published' && failPublishedOnce) {
      failPublishedOnce = false;
      throw const NoticeServiceException('network_unavailable');
    }
    if (status == 'archived' && failArchivedOnce) {
      failArchivedOnce = false;
      throw const NoticeServiceException('network_unavailable');
    }
    return NoticePage(
      items: [_notice('$status-old', status, 10)],
      cursor: null,
      hasMore: false,
    );
  }
}

class _PagedEvents extends EventService {
  _PagedEvents() : super(firestore: _UnusedFirestore());
  final calls = <String>[];
  bool failNextOnce = true;

  @override
  Future<EventPage> getEventsPage({
    required bool active,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    expect(pageSize, 30);
    calls.add('${active ? 'active' : 'hidden'}:${after == null ? 'first' : 'next'}');
    if (after == null) {
      final id = active ? 'active-new' : 'hidden-new';
      return EventPage(
        items: [_event(id, active, 30)],
        cursor: _Cursor(id),
        hasMore: true,
      );
    }
    if (active && failNextOnce) {
      failNextOnce = false;
      throw const EventServiceException('network_unavailable');
    }
    return EventPage(
      items: [_event(active ? 'active-old' : 'hidden-old', active, 10)],
      cursor: null,
      hasMore: false,
    );
  }
}

void main() {
  test('ordinary member reads published notices only and retries next page', () async {
    final service = _PagedNotices();
    final controller = NoticeController(
      service: service, auth: _TestAuth('member'),
    );
    await controller.load();
    expect(service.calls, ['published:first']);
    expect(controller.published.map((value) => value.id), ['published-new']);
    expect(controller.publishedHasMore.value, isTrue);
    expect(controller.unpublished, isEmpty);
    await controller.loadMorePublished();
    expect(controller.publishedPageErrorCode.value, 'network_unavailable');
    expect(controller.published.map((value) => value.id), ['published-new']);
    await controller.loadMorePublished();
    expect(controller.published.map((value) => value.id),
        ['published-new', 'published-old']);
    expect(controller.publishedHasMore.value, isFalse);
    await controller.loadMorePublished();
    expect(service.calls, [
      'published:first', 'published:next', 'published:next',
    ]);
  });

  test('leader reviews both notice states without cursor loss on partial failure', () async {
    final service = _PagedNotices();
    final controller = NoticeController(
      service: service, auth: _TestAuth('leader'),
    );
    await controller.load();
    expect(controller.unpublished.map((value) => value.id),
        ['draft-new', 'archived-new']);
    expect(controller.unpublishedHasMore.value, isTrue);
    await controller.loadMoreUnpublished();
    expect(controller.unpublishedPageErrorCode.value, 'network_unavailable');
    expect(controller.unpublished.map((value) => value.id),
        ['draft-new', 'archived-new']);
    await controller.loadMoreUnpublished();
    expect(controller.unpublishedPageErrorCode.value, isEmpty);
    expect(controller.unpublished.map((value) => value.id), [
      'draft-new', 'archived-new', 'archived-old', 'draft-old',
    ]);
    expect(controller.unpublishedHasMore.value, isFalse);
    expect(service.calls.where((value) => value == 'draft:next').length, 2);
    expect(service.calls.where((value) => value == 'archived:next').length, 2);
  });

  test('member event pagination never fetches hidden events', () async {
    final service = _PagedEvents();
    final controller = EventController(
      service: service, authController: _TestAuth('member'),
    );
    await controller.loadEvents();
    expect(service.calls, ['active:first']);
    expect(controller.activeEvents.map((value) => value.id), ['active-new']);
    await controller.loadMoreActive();
    expect(controller.activePageErrorCode.value, 'network_unavailable');
    expect(controller.activeEvents.map((value) => value.id), ['active-new']);
    await controller.loadMoreActive();
    expect(controller.activeEvents.map((value) => value.id),
        ['active-new', 'active-old']);
    expect(controller.activeHasMore.value, isFalse);
    expect(service.calls, ['active:first', 'active:next', 'active:next']);
  });

  test('leader can load hidden event pages independently of public pages', () async {
    final service = _PagedEvents();
    final controller = EventController(
      service: service, authController: _TestAuth('leader'),
    );
    await controller.loadEvents();
    expect(service.calls, ['active:first', 'hidden:first']);
    expect(controller.hiddenEvents.map((value) => value.id), ['hidden-new']);
    await controller.loadMoreHidden();
    expect(controller.hiddenEvents.map((value) => value.id),
        ['hidden-new', 'hidden-old']);
    expect(controller.hiddenHasMore.value, isFalse);
    expect(controller.activeEvents.map((value) => value.id), ['active-new']);
  });
}
