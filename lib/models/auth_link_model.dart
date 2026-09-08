import 'package:cloud_firestore/cloud_firestore.dart';

class AuthLinkModel {
  static const Set<String> _fields = {
    'user_id',
    'active',
    'created_at',
    'created_by',
  };

  final String firebaseAuthUid;
  final String userId;
  final bool active;
  final DateTime createdAt;
  final String createdBy;

  const AuthLinkModel({
    required this.firebaseAuthUid,
    required this.userId,
    required this.active,
    required this.createdAt,
    required this.createdBy,
  });

  factory AuthLinkModel.fromMap(
    Map<String, dynamic> map,
    String firebaseAuthUid,
  ) {
    final keys = map.keys.toSet();
    if (keys.length != _fields.length || !keys.containsAll(_fields)) {
      throw const FormatException('AuthLink has missing or unapproved fields.');
    }
    final userId = map['user_id'];
    final active = map['active'];
    final createdAt = map['created_at'];
    final createdBy = map['created_by'];
    if (userId is! String || userId.isEmpty || userId.contains('/')) {
      throw const FormatException('user_id must be a valid document ID.');
    }
    if (active is! bool) throw const FormatException('active must be a bool.');
    if (createdAt is! Timestamp) {
      throw const FormatException('created_at must be a Timestamp.');
    }
    if (createdBy is! String) {
      throw const FormatException('created_by must be a string.');
    }
    return AuthLinkModel(
      firebaseAuthUid: firebaseAuthUid,
      userId: userId,
      active: active,
      createdAt: createdAt.toDate(),
      createdBy: createdBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'active': active,
    'created_at': Timestamp.fromDate(createdAt),
    'created_by': createdBy,
  };
}
