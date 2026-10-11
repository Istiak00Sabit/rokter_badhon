import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/models/event_media_model.dart';
import 'package:rokter_badhon/models/event_model.dart';
import 'package:rokter_badhon/models/committee_media_model.dart';
import 'package:rokter_badhon/models/committee_term_model.dart';
import 'package:rokter_badhon/services/event_service.dart';
import 'package:rokter_badhon/services/committee_service.dart';
import 'package:rokter_badhon/views/event_detail_screen.dart';
import 'package:rokter_badhon/views/committee_screen.dart';

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only cursor object. No Firestore methods are invoked on it.
// ignore: subtype_of_sealed_class
class _Cursor implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _date = DateTime.utc(2026, 10, 11);

EventMediaModel _eventMedia(String id, int order) => EventMediaModel(
  id: id,
  eventId: 'event-1',
  imageUrl: 'https://example.invalid/$id.jpg',
  caption: 'Image $id',
  sortOrder: order,
  active: true,
  uploadedAt: _date,
  uploadedBy: 'operator',
  provider: null,
  providerPublicId: null,
);

CommitteeMediaModel _committeeMedia(String id, int order) => CommitteeMediaModel(
  id: id,
  termId: '2025-2027',
  imageUrl: 'https://example.invalid/$id.jpg',
  caption: 'Image $id',
  sortOrder: order,
  active: true,
  uploadedAt: _date,
  uploadedBy: 'operator',
  provider: null,
  providerPublicId: null,
);

class _EventService extends EventService {
  _EventService() : super(firestore: _UnusedFirestore());
  final firstCursor = _Cursor();
  bool failOnce = true;
  int nextCalls = 0;

  @override
  Future<EventDetail> getDetail(EventModel event, {
    bool includeHiddenMedia = false,
  }) async {
    expect(includeHiddenMedia, false);
    return EventDetail(
      event, [_eventMedia('first', 1)],
      activeCursor: firstCursor,
      hasMoreActive: true,
    );
  }

  @override
  Future<EventMediaPage> getMediaPage(
    String eventId, {
    required bool active,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 20,
  }) async {
    expect(eventId, 'event-1');
    expect(active, true);
    expect(identical(after, firstCursor), true);
    expect(pageSize, 20);
    nextCalls++;
    if (failOnce) {
      failOnce = false;
      throw const EventServiceException('network_unavailable');
    }
    return EventMediaPage(
      items: [_eventMedia('second', 2)],
      cursor: null,
      hasMore: false,
    );
  }
}

class _CommitteeService extends CommitteeService {
  _CommitteeService() : super(firestore: _UnusedFirestore());
  final firstCursor = _Cursor();
  bool failOnce = true;
  int nextCalls = 0;

  @override
  Future<CommitteeMediaPage> getActiveMediaPage(
    String termId, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 20,
  }) async {
    expect(termId, '2025-2027');
    expect(identical(after, firstCursor), true);
    expect(pageSize, 20);
    nextCalls++;
    if (failOnce) {
      failOnce = false;
      throw const CommitteeDataException('Synthetic network failure.');
    }
    return CommitteeMediaPage(
      items: [_committeeMedia('second', 2)],
      cursor: null,
      hasMore: false,
    );
  }
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('event gallery retains first media on failed next page and retry',
      (tester) async {
    final event = EventModel(
      id: 'event-1',
      title: 'Synthetic Event',
      description: null,
      eventType: 'meeting',
      eventDate: _date,
      location: null,
      coverImageUrl: null,
      active: true,
      createdAt: _date,
      createdBy: 'operator',
      updatedAt: null,
      updatedBy: null,
    );
    final service = _EventService();
    await tester.pumpWidget(GetMaterialApp(
      home: EventDetailScreen(event: event, service: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Image first'), findsOneWidget);
    expect(find.text('load_more'), findsOneWidget);
    await tester.tap(find.text('load_more'));
    await tester.pumpAndSettle();
    expect(find.text('Image first'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.text('Image first'), findsOneWidget);
    expect(find.text('Image second'), findsOneWidget);
    expect(service.nextCalls, 2);
    expect(find.text('load_more'), findsNothing);
  });

  testWidgets('committee gallery retry preserves active term media',
      (tester) async {
    final service = _CommitteeService();
    final term = CommitteeTermModel(
      id: '2025-2027',
      name: '2025–2027',
      startYear: 2025,
      endYear: 2027,
      startDate: null,
      endDate: null,
      active: true,
      groupPhotoUrl: null,
      createdAt: _date,
      createdBy: 'operator',
    );
    final roster = CommitteeRoster(
      term: term,
      members: const [],
      gallery: [_committeeMedia('first', 1)],
      galleryCursor: service.firstCursor,
      galleryHasMore: true,
    );
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: ListView(
          children: [CommitteeRosterView(roster: roster, service: service)],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Image first'), findsOneWidget);
    await tester.tap(find.text('load_more'));
    await tester.pumpAndSettle();
    expect(find.text('retry'), findsOneWidget);
    expect(find.text('Image first'), findsOneWidget);
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.text('Image second'), findsOneWidget);
    expect(service.nextCalls, 2);
    expect(find.text('load_more'), findsNothing);
  });
}
