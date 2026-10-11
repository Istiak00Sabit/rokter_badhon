import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_media_model.dart';
import '../models/event_model.dart';

class EventServiceException implements Exception {
  final String code;
  const EventServiceException(this.code);
}

class EventMediaPage {
  final List<EventMediaModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const EventMediaPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class EventDetail {
  final EventModel event;
  final List<EventMediaModel> gallery;
  final DocumentSnapshot<Map<String, dynamic>>? activeCursor;
  final DocumentSnapshot<Map<String, dynamic>>? hiddenCursor;
  final bool hasMoreActive;
  final bool hasMoreHidden;

  const EventDetail(
    this.event,
    this.gallery, {
    this.activeCursor,
    this.hiddenCursor,
    this.hasMoreActive = false,
    this.hasMoreHidden = false,
  });
}

class EventPage {
  final List<EventModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const EventPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });
}

class EventService {
  static const eventsCollection = 'events';
  static const mediaCollection = 'event_media';
  final FirebaseFirestore _firestore;

  EventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<EventPage> getEventsPage({
    required bool active,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 30,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw const EventServiceException('invalid_limit');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(eventsCollection)
          .where('active', isEqualTo: active)
          .orderBy('event_date', descending: true);
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      final events = docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (events.any((event) => event.active != active)) {
        throw const EventDataException(
          'Event query returned an unapproved state.',
        );
      }
      return EventPage(
        items: List<EventModel>.unmodifiable(events),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on EventDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventServiceException(_safeCode(error.code));
    }
  }

  /// Compatibility callers get the bounded first page.
  Future<List<EventModel>> getActiveEvents() async =>
      (await getEventsPage(active: true)).items;

  Future<List<EventModel>> getHiddenEvents() async =>
      (await getEventsPage(active: false)).items;

  Future<EventMediaPage> getMediaPage(
    String eventId, {
    required bool active,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 20,
  }) async {
    if (eventId.isEmpty || eventId.contains('/')) {
      throw const EventDataException('Invalid event ID.');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw const EventServiceException('invalid_limit');
    }
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(mediaCollection)
          .where('event_id', isEqualTo: eventId)
          .where('active', isEqualTo: active)
          .orderBy('sort_order')
          .orderBy(FieldPath.documentId);
      if (after != null) query = query.startAfterDocument(after);
      final snapshot = await query.limit(pageSize + 1).get();
      final docs = snapshot.docs.take(pageSize).toList(growable: false);
      final values = docs
          .map((doc) => EventMediaModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (values.any(
        (item) => item.active != active || item.eventId != eventId,
      )) {
        throw const EventDataException(
          'Event gallery returned an unapproved record.',
        );
      }
      return EventMediaPage(
        items: List<EventMediaModel>.unmodifiable(values),
        cursor: docs.isEmpty ? null : docs.last,
        hasMore: snapshot.docs.length > pageSize,
      );
    } on EventDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventServiceException(_safeCode(error.code));
    }
  }

  Future<EventDetail> getDetail(
    EventModel event, {
    bool includeHiddenMedia = false,
  }) async {
    if (event.id.isEmpty || event.id.contains('/')) {
      throw const EventDataException('Invalid event ID.');
    }
    final activePage = await getMediaPage(event.id, active: true);
    final hiddenPage = includeHiddenMedia
        ? await getMediaPage(event.id, active: false)
        : null;
    final gallery = [
      ...activePage.items,
      ...?hiddenPage?.items,
    ]..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
    return EventDetail(
      event,
      List<EventMediaModel>.unmodifiable(gallery),
      activeCursor: activePage.cursor,
      hiddenCursor: hiddenPage?.cursor,
      hasMoreActive: activePage.hasMore,
      hasMoreHidden: hiddenPage?.hasMore ?? false,
    );
  }

  static String _safeCode(String code) => switch (code) {
    'permission-denied' => 'permission_denied',
    'failed-precondition' => 'query_unavailable',
    'unavailable' || 'network-request-failed' => 'network_unavailable',
    _ => 'operation_failed',
  };
}
