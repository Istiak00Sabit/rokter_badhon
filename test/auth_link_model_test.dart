import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/auth_link_model.dart';

void main() {
  final timestamp = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
  Map<String, dynamic> validLink({Map<String, dynamic> changes = const {}}) => {
    'user_id': 'application-user-id',
    'active': true,
    'created_at': timestamp,
    'created_by': 'creator-user-id',
    ...changes,
  };

  test('AuthLink uses Firebase UID only as document identity', () {
    final link = AuthLinkModel.fromMap(validLink(), 'firebase-auth-uid');
    expect(link.firebaseAuthUid, 'firebase-auth-uid');
    expect(link.userId, 'application-user-id');
    expect(link.createdAt, timestamp.toDate());
    expect(link.toMap(), validLink());
    expect(link.toMap(), isNot(contains('firebase_auth_uid')));
  });

  test('AuthLink requires its exact schema and types', () {
    for (final field in ['user_id', 'active', 'created_at', 'created_by']) {
      final missing = validLink()..remove(field);
      expect(
        () => AuthLinkModel.fromMap(missing, 'uid'),
        throwsFormatException,
      );
    }
    for (final changes in [
      {'active': 'true'},
      {'created_at': '2026-01-01'},
      {'user_id': 'bad/id'},
      {'extra': true},
    ]) {
      expect(
        () => AuthLinkModel.fromMap(validLink(changes: changes), 'uid'),
        throwsFormatException,
      );
    }
  });
}
