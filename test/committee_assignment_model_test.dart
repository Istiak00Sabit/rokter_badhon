import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/committee_assignment_model.dart';

Map<String, dynamic> validAssignment({
  Map<String, dynamic> changes = const {},
}) => {
  'user_id': 'user-id',
  'term_id': 'term-id',
  'position': 'president',
  'active': true,
  'assigned_at': Timestamp.fromMillisecondsSinceEpoch(1735689600000),
  'assigned_by': 'assigner-id',
  'ended_at': null,
  ...changes,
};

void main() {
  test('CommitteeAssignment strictly parses the exact schema', () {
    final assignment = CommitteeAssignmentModel.fromMap(
      validAssignment(),
      'assignment-id',
    );
    expect(assignment.position, 'president');
    expect(assignment.toMap().keys.toSet(), validAssignment().keys.toSet());

    expect(
      () => CommitteeAssignmentModel.fromMap({
        ...validAssignment(),
        'access_role': 'leader',
      }, 'assignment-id'),
      throwsFormatException,
    );
    expect(
      () => CommitteeAssignmentModel.fromMap(
        validAssignment(changes: {'assigned_at': 'today'}),
        'assignment-id',
      ),
      throwsFormatException,
    );
  });

  test('historical position is preserved on an ended assignment', () {
    final endedAt = Timestamp.fromMillisecondsSinceEpoch(1767225600000);
    final assignment = CommitteeAssignmentModel.fromMap(
      validAssignment(
        changes: {
          'position': 'former_general_secretary',
          'active': false,
          'ended_at': endedAt,
        },
      ),
      'historical-id',
    );
    expect(assignment.position, 'former_general_secretary');
    expect(assignment.active, isFalse);
    expect(assignment.endedAt, endedAt.toDate());
  });

  test('ended_at accepts only a Timestamp or null', () {
    expect(
      CommitteeAssignmentModel.fromMap(
        validAssignment(changes: {'active': false}),
        'assignment-id',
      ).endedAt,
      isNull,
    );
    expect(
      () => CommitteeAssignmentModel.fromMap(
        validAssignment(changes: {'ended_at': '2026-01-01'}),
        'assignment-id',
      ),
      throwsFormatException,
    );
  });

  test('position never maps to access_role', () {
    final assignment = CommitteeAssignmentModel.fromMap(
      validAssignment(changes: {'position': 'developer_admin'}),
      'assignment-id',
    );
    expect(assignment.position, 'developer_admin');
    expect(assignment.toMap(), isNot(contains('access_role')));
  });
}
