import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/event_media_model.dart';
import 'package:rokter_badhon/models/event_model.dart';

Map<String, dynamic> event([Map<String, dynamic> changes = const {}]) => {
  'title': 'Blood camp',
  'description': null,
  'event_type': 'blood_donation_campaign',
  'event_date': Timestamp(10, 0),
  'location': 'Ghatail',
  'cover_image_url': null,
  'active': true,
  'created_at': Timestamp(1, 0),
  'created_by': 'user-1',
  'updated_at': null,
  'updated_by': null,
  ...changes,
};
Map<String, dynamic> media([Map<String, dynamic> changes = const {}]) => {
  'event_id': 'event-1',
  'image_url': 'https://example.test/image.jpg',
  'caption': null,
  'sort_order': 0,
  'active': true,
  'uploaded_at': Timestamp(2, 0),
  'uploaded_by': 'user-1',
  'provider': null,
  'provider_public_id': null,
  ...changes,
};

void main() {
  test('Event exact schema parses strict Firestore values', () {
    final value = EventModel.fromMap(event(), 'event-1');
    expect(value.eventType, 'blood_donation_campaign');
    expect(value.active, isTrue);
    expect(
      () => EventModel.fromMap(event({'legacy': true}), 'event-1'),
      throwsA(isA<EventDataException>()),
    );
    expect(
      () => EventModel.fromMap(event({'event_date': 'today'}), 'event-1'),
      throwsA(isA<EventDataException>()),
    );
    expect(
      () => EventModel.fromMap(
        event({'cover_image_url': 'http://bad.test/a.jpg'}),
        'event-1',
      ),
      throwsA(isA<EventDataException>()),
    );
  });

  test('Event update metadata must be paired and type is recognized', () {
    expect(
      () =>
          EventModel.fromMap(event({'updated_at': Timestamp(3, 0)}), 'event-1'),
      throwsA(isA<EventDataException>()),
    );
    expect(
      () => EventModel.fromMap(event({'event_type': 'legacy'}), 'event-1'),
      throwsA(isA<EventDataException>()),
    );
  });

  test(
    'EventMedia exact schema enforces URL, ordering and provider relation',
    () {
      expect(EventMediaModel.fromMap(media(), 'media-1').sortOrder, 0);
      expect(
        () => EventMediaModel.fromMap(media({'sort_order': -1}), 'media-1'),
        throwsA(isA<EventDataException>()),
      );
      expect(
        () => EventMediaModel.fromMap(
          media({'image_url': 'http://bad.test/a.jpg'}),
          'media-1',
        ),
        throwsA(isA<EventDataException>()),
      );
      expect(
        () => EventMediaModel.fromMap(
          media({'provider_public_id': 'orphan'}),
          'media-1',
        ),
        throwsA(isA<EventDataException>()),
      );
    },
  );

  test(
    'Event Flutter source is read-only and queries are scoped and ordered',
    () {
      final source = File('lib/services/event_service.dart').readAsStringSync();
      expect(source, contains("where('active', isEqualTo: active)"));
      expect(source, contains("orderBy('event_date', descending: true)"));
      expect(source, contains("where('event_id', isEqualTo: event.id)"));
      expect(source, contains("orderBy('sort_order')"));
      expect(source, isNot(contains('.add(')));
      expect(source, isNot(contains('.set(')));
      expect(source, isNot(contains('.update(')));
      expect(source, isNot(contains('.delete(')));
    },
  );
}
