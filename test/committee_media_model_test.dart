import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/committee_media_model.dart';

Map<String, dynamic> validMedia({Map<String, dynamic> changes = const {}}) => {
  'term_id': 'term-id',
  'image_url': 'https://example.test/gallery.jpg',
  'caption': 'Committee gathering',
  'sort_order': 2,
  'active': true,
  'uploaded_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
  'uploaded_by': 'operator-id',
  'provider': null,
  'provider_public_id': null,
  ...changes,
};

void main() {
  test('CommitteeMedia strictly parses the exact approved schema', () {
    final media = CommitteeMediaModel.fromMap(validMedia(), 'media-id');
    expect(media.termId, 'term-id');
    expect(media.sortOrder, 2);
    expect(media.caption, 'Committee gathering');
    expect(media.toMap().keys.toSet(), validMedia().keys.toSet());
    expect(
      () => CommitteeMediaModel.fromMap({
        ...validMedia(),
        'role': 'leader',
      }, 'media-id'),
      throwsFormatException,
    );
    final missing = validMedia()..remove('uploaded_at');
    expect(
      () => CommitteeMediaModel.fromMap(missing, 'media-id'),
      throwsFormatException,
    );
  });

  test('CommitteeMedia requires HTTPS and a nonnegative integer order', () {
    for (final change in [
      {'image_url': 'http://example.test/gallery.jpg'},
      {'image_url': ''},
      {'sort_order': 1.5},
      {'sort_order': -1},
    ]) {
      expect(
        () => CommitteeMediaModel.fromMap(
          validMedia(changes: change),
          'media-id',
        ),
        throwsFormatException,
      );
    }
  });

  test('CommitteeMedia has no current-time fallback', () {
    for (final value in [null, '2026-01-01', DateTime(2026)]) {
      expect(
        () => CommitteeMediaModel.fromMap(
          validMedia(changes: {'uploaded_at': value}),
          'media-id',
        ),
        throwsFormatException,
      );
    }
  });

  test('nullable metadata stays generic and public ID requires provider', () {
    final media = CommitteeMediaModel.fromMap(
      validMedia(
        changes: {
          'caption': null,
          'provider': 'approved_provider',
          'provider_public_id': 'public-id',
        },
      ),
      'media-id',
    );
    expect(media.caption, isNull);
    expect(media.provider, 'approved_provider');
    expect(
      () => CommitteeMediaModel.fromMap(
        validMedia(changes: {'provider_public_id': 'orphan'}),
        'media-id',
      ),
      throwsFormatException,
    );
  });
}
