import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/user_model.dart';

Map<String, dynamic> validUser({Map<String, dynamic> changes = const {}}) => {
  'name': 'Synthetic User',
  'phone': '00000000000',
  'email': 'user@example.test',
  'blood_group': 'A+',
  'profession': null,
  'address': null,
  'photo_url': null,
  'access_role': 'member',
  'active': true,
  'login_enabled': true,
  'preferred_language': null,
  'created_at': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
  'created_by': null,
  'updated_at': Timestamp.fromMillisecondsSinceEpoch(1700000001000),
  'updated_by': null,
  ...changes,
};

void main() {
  test('valid v1.2.1 User round trips with document identity', () {
    final map = validUser();
    final user = UserModel.fromMap(map, 'application-user-id');

    expect(user.id, 'application-user-id');
    expect(user.accessRole, 'member');
    expect(user.active, isTrue);
    expect(user.loginEnabled, isTrue);
    expect(user.createdAt, (map['created_at'] as Timestamp).toDate());
    expect(user.updatedAt, (map['updated_at'] as Timestamp).toDate());
    expect(user.toMap(), map);
  });

  for (final field in ['access_role', 'active', 'login_enabled']) {
    test('missing security field $field fails closed', () {
      final map = validUser()..remove(field);
      expect(() => UserModel.fromMap(map, 'user-id'), throwsFormatException);
    });

    test('malformed security field $field fails closed', () {
      expect(
        () => UserModel.fromMap(validUser(changes: {field: null}), 'user-id'),
        throwsFormatException,
      );
    });
  }

  test('unknown access role is preserved only for invalidRole admission', () {
    final user = UserModel.fromMap(
      validUser(changes: {'access_role': 'admin'}),
      'user-id',
    );
    expect(user.accessRole, 'admin');
    expect(user.hasRecognizedAccessRole, isFalse);
  });

  test('photo URL follows the Rules HTTPS invariant', () {
    for (final value in ['http://example.test/photo.jpg', 'https:///photo.jpg']) {
      expect(
        () => UserModel.fromMap(
          validUser(changes: {'photo_url': value}),
          'user-id',
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'timestamps must be Firestore Timestamps with no current-time fallback',
    () {
      for (final value in [null, '2026-01-01', DateTime(2026)]) {
        expect(
          () => UserModel.fromMap(
            validUser(changes: {'created_at': value}),
            'user-id',
          ),
          throwsFormatException,
        );
      }
      final missing = validUser()..remove('updated_at');
      expect(
        () => UserModel.fromMap(missing, 'user-id'),
        throwsFormatException,
      );
    },
  );

  test('legacy identity, role, and committee fields are rejected', () {
    for (final field in [
      'uid',
      'auth_uid',
      'role',
      'position',
      'committee_year',
    ]) {
      expect(
        () =>
            UserModel.fromMap(validUser(changes: {field: 'legacy'}), 'user-id'),
        throwsFormatException,
      );
    }
    expect(
      UserModel.fromMap(validUser(), 'user-id').toMap(),
      isNot(contains('uid')),
    );
  });
}
