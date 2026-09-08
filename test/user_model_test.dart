import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/user_model.dart';

void main() {
  test('document identity never falls back to a legacy uid field', () {
    final user = UserModel.fromMap({
      'uid': 'old-auth-or-document-id',
      'role': 'vp',
    }, 'organization-user-id');

    expect(user.id, 'organization-user-id');
    expect(user.authUid, isNull);
    expect(user.loginEnabled, isFalse);
    expect(user.toMap(), isNot(contains('uid')));
    expect(user.toMap(), isNot(contains('id')));
    expect(user.toMap()['auth_uid'], isNull);
    expect(user.toMap()['login_enabled'], isFalse);
  });

  test('linked admin round trip preserves independent identities and fields', () {
    final joined = DateTime(2024, 5, 10);
    final user = UserModel.fromMap({
      'auth_uid': 'firebase-auth-id',
      'login_enabled': true,
      'name': 'Admin',
      'email': 'admin@example.com',
      'phone': '01700000000',
      'blood_group': 'A+',
      'address': 'Ghatail',
      'photo': 'photo-path',
      'role': 'admin',
      'committee_year': 2024,
      'joined_date': Timestamp.fromDate(joined),
      'active': true,
    }, 'independent-document-id');
    final restored = UserModel.fromMap(user.toMap(), user.id);

    expect(restored.id, 'independent-document-id');
    expect(restored.authUid, 'firebase-auth-id');
    expect(restored.loginEnabled, isTrue);
    expect(restored.role, 'admin');
    expect(restored.committeeYear, 2024);
    expect(restored.joinedDate, joined);
    expect(restored.toMap(), user.toMap());
  });

  test('copy can explicitly clear Auth linkage without changing entity id', () {
    final linked = UserModel.fromMap({
      'auth_uid': 'auth-id',
      'login_enabled': true,
      'role': 'gs',
    }, 'entity-id');

    expect(linked.copyWith(name: 'Updated').authUid, 'auth-id');
    final unlinked = linked.copyWith(authUid: null, loginEnabled: false);
    expect(unlinked.id, 'entity-id');
    expect(unlinked.authUid, isNull);
    expect(unlinked.loginEnabled, isFalse);
    expect(unlinked.role, 'gs');
  });

  test('legacy admin login is not inferred by the domain model', () {
    final user = UserModel.fromMap({
      'role': 'admin',
      'uid': 'auth-id',
    }, 'auth-id');

    expect(user.authUid, isNull);
    expect(user.loginEnabled, isFalse);
  });
}
