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

class EventService {
  static const eventsCollection = 'events';
  static const mediaCollection = 'event_media';
  final FirebaseFirestore _firestore;

  EventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<EventModel>> getActiveEvents() => _events(active: true);
  Future<List<EventModel>> getHiddenEvents() => _events(active: false);

  Future<List<EventModel>> _events({required bool active}) async {
    try {
      final snapshot = await _firestore
          .collection(eventsCollection)
          .where('active', isEqualTo: active)
          .orderBy('event_date', descending: true)
          .get();
      final events = snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
      if (events.any((event) => event.active != active)) {
        throw const EventDataException(
          'Event query returned an unapproved state.',
        );
      }
      return events;
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
