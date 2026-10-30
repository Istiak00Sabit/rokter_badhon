import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Spark plan implementation: all privileged changes are atomic batches
/// guarded by deployed Firestore Security Rules. No Cloud Functions required.
class AdminCallException implements Exception {
  final String code;
  const AdminCallException(this.code);
}

class AdminUserSummary {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool active;
  final bool loginEnabled;

  const AdminUserSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.active,
    required this.loginEnabled,
  });

  factory AdminUserSummary.fromData(Map<String, dynamic> json, String id) {
    return AdminUserSummary(
      id: id,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['access_role'] as String,
      active: json['active'] as bool,
      loginEnabled: json['login_enabled'] as bool,
    );
  }
}

class AdminFunctionsService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AdminFunctionsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<String> _actorId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AdminCallException('unauthenticated');
    try {
      final link = await _firestore.collection('auth_links').doc(uid).get();
      final id = link.data()?['user_id'];
      if (id is! String || id.isEmpty) {
        throw const AdminCallException('permission_denied');
      }
      return id;
    } on FirebaseException catch (error) {
      throw AdminCallException(error.code);
    }
  }

  static void _checkReason(String reason) {
    if (reason.trim().length < 10 || reason.trim().length > 500) {
      throw const AdminCallException('admin_reason_required');
    }
  }

  Future<void> decideRegistration({
    required String applicantUid,
    required bool approve,
    required String reason,
  }) async {
    _checkReason(reason);
    if (applicantUid.isEmpty || applicantUid.contains('/')) {
      throw const AdminCallException('invalid_argument');
    }
    final actor = await _actorId();
    if (_auth.currentUser?.uid == applicantUid) {
      throw const AdminCallException('permission_denied');
    }
    try {
      final requestRef = _firestore.collection('registration_requests').doc(applicantUid);
      final existing = await requestRef.get();
      final raw = existing.data();
      if (raw == null || raw['status'] != 'pending' || raw['auth_uid'] != applicantUid) {
        throw const AdminCallException('already_decided');
      }
      final batch = _firestore.batch();
      final reviewRef = _firestore.collection('registration_review_events').doc(applicantUid);
      final now = FieldValue.serverTimestamp();
      batch.set(reviewRef, {
        'action': approve ? 'approve' : 'reject',
        'actor_user_id': actor,
        'reviewed_at': now,
        'reason': reason.trim(),
      });

      if (approve) {
        final phone = raw['phone'];
        if (phone is! String || !RegExp(r'^01[3-9][0-9]{8}$').hasMatch(phone)) {
          throw const AdminCallException('invalid_phone');
        }
        final users = _firestore.collection('users');
        // Older imported people may not have a phone-claim key. Check the
        // legacy directory too; this is a preflight, not a uniqueness lock.
        final existingPhone = await users.where('phone', isEqualTo: phone).limit(1).get();
        if (existingPhone.docs.isNotEmpty) {
          throw const AdminCallException('existing_phone_review_required');
        }
        final claimRef = _firestore.collection('registration_phone_claims').doc(phone);
        final claim = await claimRef.get();
        if (claim.exists) throw const AdminCallException('existing_phone_review_required');
        final userRef = users.doc(applicantUid);
        final linkRef = _firestore.collection('auth_links').doc(applicantUid);
        final directoryRef = _firestore.collection('user_directory').doc(applicantUid);
        final user = {
          'name': raw['name'],
          'phone': phone,
          'email': raw['email'],
          'blood_group': raw['blood_group'],
          'profession': raw['profession'],
          'address': raw['address'],
          'photo_url': null,
          'access_role': 'member',
          'active': true,
          'login_enabled': true,
          'preferred_language': null,
          'created_at': now,
          'created_by': actor,
          'updated_at': now,
          'updated_by': actor,
        };
        batch.set(userRef, user);
        batch.set(directoryRef, {
          'name': user['name'],
          'phone': user['phone'],
          'blood_group': user['blood_group'],
          'profession': user['profession'],
          'photo_url': null,
          'active': true,
        });
        batch.set(linkRef, {
          'user_id': applicantUid,
          'active': true,
          'created_at': now,
          'created_by': actor,
        });
        batch.set(claimRef, {
          'user_id': applicantUid,
          'claimed_at': now,
          'claimed_by': actor,
        });
        batch.update(requestRef, {
          'status': 'approved',
          'approved_by': actor,
          'approved_at': now,
          'linked_user_id': applicantUid,
        });
      } else {
        batch.update(requestRef, {
          'status': 'rejected',
          'rejected_by': actor,
          'rejected_at': now,
        });
      }
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AdminCallException(error.code);
    }
  }

  Future<({List<AdminUserSummary> users, bool hasMore})> listUsers() async {
    try {
      final snapshot = await _firestore.collection('users').limit(81).get();
      return (
        users: snapshot.docs.take(80)
            .map((item) => AdminUserSummary.fromData(item.data(), item.id))
            .toList(growable: false),
        hasMore: snapshot.docs.length > 80,
      );
    } on FirebaseException catch (error) {
      throw AdminCallException(error.code);
    } on FormatException {
      throw const AdminCallException('malformed_data');
    }
  }

  Future<void> manageUser({
    required String userId,
    required String action,
    required String reason,
    String? role,
  }) async {
    _checkReason(reason);
    final actor = await _actorId();
    if (userId == actor || userId.isEmpty || userId.contains('/')) {
      throw const AdminCallException('permission_denied');
    }
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final original = (await userRef.get()).data();
      if (original == null || original['access_role'] == 'developer_admin') {
        throw const AdminCallException('permission_denied');
      }
      final previous = {
        'access_role': original['access_role'],
        'active': original['active'],
        'login_enabled': original['login_enabled'],
      };
      final updated = Map<String, dynamic>.from(previous);
      switch (action) {
        case 'role':
          if (!{'member','committee','executive','leader'}.contains(role)) {
            throw const AdminCallException('invalid_argument');
          }
          updated['access_role'] = role;
        case 'activate':
          updated['active'] = true;
        case 'deactivate':
          updated['active'] = false;
        case 'enable_login':
          if (original['active'] != true) {
            throw const AdminCallException('inactive_user');
          }
          updated['login_enabled'] = true;
        case 'disable_login':
          updated['login_enabled'] = false;
        default:
          throw const AdminCallException('invalid_argument');
      }
      if (previous.toString() == updated.toString()) {
        throw const AdminCallException('no_change');
      }
      final now = FieldValue.serverTimestamp();
      final op = _firestore.collection('admin_actions').doc();
      final batch = _firestore.batch();
      batch.update(userRef, {
        ...updated,
        'last_admin_action_id': op.id,
        'updated_at': now,
        'updated_by': actor,
      });
      if (updated['active'] != previous['active']) {
        batch.update(_firestore.collection('user_directory').doc(userId), {
          'active': updated['active'],
        });
      }
      batch.set(op, {
        'user_id': userId,
        'actor_user_id': actor,
        'occurred_at': now,
        'reason': reason.trim(),
        'before': previous,
        'after': updated,
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AdminCallException(error.code);
    }
  }

  Future<void> updateProfilePhoto(String? photoUrl) async {
    if (photoUrl != null) {
      final uri = Uri.tryParse(photoUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || photoUrl.length > 2048) {
        throw const AdminCallException('invalid_photo_url');
      }
    }
    final actor = await _actorId();
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(actor), {
        'photo_url': photoUrl,
        'updated_by': actor,
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.update(_firestore.collection('user_directory').doc(actor), {
        'photo_url': photoUrl,
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AdminCallException(error.code);
    }
  }
}
