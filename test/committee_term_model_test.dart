import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/committee_term_model.dart';

Map<String, dynamic> validTerm({Map<String, dynamic> changes = const {}}) => {
  'name': '2025-2027',
  'start_year': 2025,
  'end_year': 2027,
  'start_date': Timestamp.fromMillisecondsSinceEpoch(1735689600000),
  'end_date': null,
  'active': true,
  'group_photo_url': 'https://example.test/committee.jpg',
  'created_at': Timestamp.fromMillisecondsSinceEpoch(1735689600000),
  'created_by': 'creator-id',
  ...changes,
};

void main() {
  test('CommitteeTerm strictly parses the exact DATA_MODEL schema', () {
    final term = CommitteeTermModel.fromMap(validTerm(), 'term-id');
    expect(term.name, '2025-2027');
    expect(term.startYear, 2025);
    expect(term.endYear, 2027);
    expect(term.groupPhotoUrl, 'https://example.test/committee.jpg');
    expect(term.toMap().keys.toSet(), validTerm().keys.toSet());

    expect(
      () => CommitteeTermModel.fromMap({
        ...validTerm(),
        'access_role': 'leader',
      }, 'term-id'),
      throwsFormatException,
    );
    final missingCreatedAt = validTerm()..remove('created_at');
    expect(
      () => CommitteeTermModel.fromMap(missingCreatedAt, 'term-id'),
      throwsFormatException,
    );
  });

  test('CommitteeTerm has no current-year or current-time fallback', () {
    for (final change in [
      {'start_year': null},
      {'end_year': '2027'},
      {'created_at': null},
      {'created_at': '2025-01-01'},
    ]) {
      expect(
        () => CommitteeTermModel.fromMap(validTerm(changes: change), 'term-id'),
        throwsFormatException,
      );
    }
  });

  test('CommitteeTerm accepts only null or HTTPS group photos', () {
    expect(
      CommitteeTermModel.fromMap(
        validTerm(changes: {'group_photo_url': null}),
        'term-id',
      ).groupPhotoUrl,
      isNull,
    );
    expect(
      () => CommitteeTermModel.fromMap(
        validTerm(changes: {'group_photo_url': 'http://example.test/a.jpg'}),
        'term-id',
      ),
      throwsFormatException,
    );
  });
}
