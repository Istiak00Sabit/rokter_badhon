import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_media_model.dart';
import '../models/event_model.dart';

class EventServiceException implements Exception {
  final String code;
  const EventServiceException(this.code);
}

class EventDetail {
  final EventModel event;
  final List<EventMediaModel> gallery;
  const EventDetail(this.event, this.gallery);
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

  Future<EventDetail> getDetail(
    EventModel event, {
    bool includeHiddenMedia = false,
  }) async {
    if (event.id.isEmpty || event.id.contains('/')) {
      throw const EventDataException('Invalid event ID.');
    }
    try {
      Future<List<EventMediaModel>> load(bool active) async {
        final snapshot = await _firestore
            .collection(mediaCollection)
            .where('event_id', isEqualTo: event.id)
            .where('active', isEqualTo: active)
            .orderBy('sort_order')
            .orderBy(FieldPath.documentId)
            .get();
        final values = snapshot.docs
            .map((doc) => EventMediaModel.fromMap(doc.data(), doc.id))
            .toList();
        if (values.any(
          (item) => item.active != active || item.eventId != event.id,
        )) {
          throw const EventDataException(
            'Event gallery returned an unapproved record.',
          );
        }
        return values;
      }

      final media = await load(true);
      if (includeHiddenMedia) media.addAll(await load(false));
      media.sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
      return EventDetail(event, media);
    } on EventDataException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventServiceException(_safeCode(error.code));
    }
  }

  static String _safeCode(String code) => switch (code) {
    'permission-denied' => 'permission_denied',
    'failed-precondition' => 'query_unavailable',
    'unavailable' || 'network-request-failed' => 'network_unavailable',
    _ => 'operation_failed',
  };
}
