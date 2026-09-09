import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/committee_assignment_model.dart';
import 'package:rokter_badhon/models/committee_term_model.dart';
import 'package:rokter_badhon/models/user_directory_model.dart';
import 'package:rokter_badhon/services/committee_service.dart';

CommitteeTermModel term(
  String id, {
  required num startYear,
  required num endYear,
  required bool active,
}) => CommitteeTermModel.fromMap({
  'name': '$startYear-$endYear',
  'start_year': startYear,
  'end_year': endYear,
  'start_date': null,
  'end_date': null,
  'active': active,
  'group_photo_url': null,
  'created_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
  'created_by': 'creator-id',
}, id);

CommitteeAssignmentModel assignment(
  String id, {
  String userId = 'user-id',
  String termId = 'term-id',
  String position = 'member_secretary',
  bool active = true,
}) => CommitteeAssignmentModel.fromMap({
  'user_id': userId,
  'term_id': termId,
  'position': position,
  'active': active,
  'assigned_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
  'assigned_by': 'assigner-id',
  'ended_at': active
      ? null
      : Timestamp.fromMillisecondsSinceEpoch(1767225600000),
}, id);

UserDirectoryModel directory(String id, {bool active = true}) =>
    UserDirectoryModel.fromMap({
      'name': 'Directory User',
      'phone': '00000000000',
      'blood_group': 'A+',
      'profession': 'Teacher',
      'photo_url': null,
      'active': active,
    }, id);

void main() {
  test('current-term selection accepts zero or one active term only', () {
    final current = term(
      'current',
      startYear: 2025,
      endYear: 2027,
      active: true,
    );
    final past = term('past', startYear: 2023, endYear: 2025, active: false);
    expect(CommitteeService.selectCurrentTerm([past, current]), same(current));
    expect(CommitteeService.selectCurrentTerm([past]), isNull);
    expect(
      () => CommitteeService.selectCurrentTerm([
        current,
        term('other', startYear: 2026, endYear: 2028, active: true),
      ]),
      throwsA(isA<CommitteeDataException>()),
    );
  });

  test('past terms are filtered and ordered newest first', () {
    final terms = CommitteeService.orderPastTerms([
      term('old', startYear: 2021, endYear: 2023, active: false),
      term('current', startYear: 2025, endYear: 2027, active: true),
      term('new', startYear: 2023, endYear: 2025, active: false),
    ]);
    expect(terms.map((item) => item.id), ['new', 'old']);
  });

  test('active assignment validation rejects inactive or other-term data', () {
    CommitteeService.validateActiveAssignments('term-id', [assignment('one')]);
    expect(
      () => CommitteeService.validateActiveAssignments('term-id', [
        assignment('ended', active: false),
      ]),
      throwsA(isA<CommitteeDataException>()),
    );
    expect(
      () => CommitteeService.validateActiveAssignments('term-id', [
        assignment('other', termId: 'other-term'),
      ]),
      throwsA(isA<CommitteeDataException>()),
    );
  });

  test(
    'directory mapping is display-only and preserves assignment position',
    () {
      final historical = assignment(
        'historical',
        userId: 'known',
        position: 'past_president',
        active: false,
      );
      final members = CommitteeService.mapDirectoryPresentation(
        [historical],
        {'known': directory('known')},
      );
      expect(members.single.directory?.name, 'Directory User');
      expect(members.single.position, 'past_president');
    },
  );

  test(
    'missing or inactive directory is handled without private User fallback',
    () {
      final item = assignment('assignment', userId: 'missing');
      expect(
        CommitteeService.mapDirectoryPresentation([item], {}).single.directory,
        isNull,
      );
      expect(
        CommitteeService.mapDirectoryPresentation(
          [item],
          {'missing': directory('missing', active: false)},
        ).single.directory,
        isNull,
      );
    },
  );

  test(
    'committee service uses scoped reads and exposes no privileged writes',
    () {
      final source = File(
        'lib/services/committee_service.dart',
      ).readAsStringSync();
      expect(source, contains(".where('active', isEqualTo: true)"));
      expect(source, contains(".where('active', isEqualTo: false)"));
      expect(source, contains(".where('term_id', isEqualTo: termId)"));
      expect(source, contains('FieldPath.documentId'));
      expect(source, isNot(contains(".collection('users')")));
      expect(source, isNot(contains('.add(')));
      expect(source, isNot(contains('.set(')));
      expect(source, isNot(contains('.update(')));
      expect(source, isNot(contains('.delete(')));
      expect(source, isNot(contains('access_role')));
    },
  );
}
