import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_identity.dart';

/// A directory-only committee addition. Login credentials and security roles
/// are never provisioned by this form. Production Auth provisioning remains a
/// separate trusted-operator operation.
class CommitteeMemberAdminException implements Exception {
  final String message;
  const CommitteeMemberAdminException(this.message);

  @override
  String toString() => message;
}

class CommitteeMemberInput {
  final String name;
  final String phone;
  final String position;
  final String? profession;
  final String? bloodGroup;

  const CommitteeMemberInput({
    required this.name,
    required this.phone,
    required this.position,
    required this.profession,
    required this.bloodGroup,
  });

  String validateAndNormalizePhone() {
    if (name.trim().isEmpty || position.trim().isEmpty) {
      throw const CommitteeMemberAdminException(
        'Name and committee position are required.',
      );
    }
    try {
      return AuthIdentity.normalizePhone(phone);
    } on FormatException {
      throw const CommitteeMemberAdminException(
        'Enter a valid Bangladeshi phone number.',
      );
    }
  }
}

class CommitteeMemberAdminService {
  final FirebaseFirestore _firestore;

  CommitteeMemberAdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Adds a committee assignment and, if needed, a login-disabled User plus
  /// the matching public directory. Runs atomically and does not alter any
  /// existing User's role, login permissions, or personal details.
  ///
  /// Access is restricted by Firestore's developer_admin authorization,
  /// independently of the UI that calls this method.
  Future<void> addMember({
    required CommitteeMemberInput input,
    required String termId,
    required String actorUserId,
  }) async {
    final phone = input.validateAndNormalizePhone();
    if (termId.isEmpty || termId.contains('/') ||
        actorUserId.isEmpty || actorUserId.contains('/')) {
      throw const CommitteeMemberAdminException('Invalid committee session.');
    }

    // Avoid silently creating a second organization User for a registered
    // phone. Firestore Rules enforce the caller's developer_admin role.
    final matches = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(2)
        .get();
    if (matches.docs.length > 1) {
      throw const CommitteeMemberAdminException(
        'More than one User has this phone number. Contact the operator.',
      );
    }

    final userId = matches.docs.isEmpty
        ? 'committee-added-' + phone
        : matches.docs.single.id;
    // Check all assignment IDs, not only the deterministic ID used by
    // this form. Imported members have serial-based IDs.
    final priorAssignments = await _firestore
        .collection('committee_assignments')
        .where('user_id', isEqualTo: userId)
        .where('term_id', isEqualTo: termId)
        .limit(1)
        .get();
    if (priorAssignments.docs.isNotEmpty) {
      throw const CommitteeMemberAdminException(
        'This User already has a committee assignment for the term.',
      );
    }

    final assignmentId = termId + '-added-' + phone;
    final termRef = _firestore.collection('committee_terms').doc(termId);
    final userRef = _firestore.collection('users').doc(userId);
    final directoryRef = _firestore.collection('user_directory').doc(userId);
    final assignmentRef = _firestore
        .collection('committee_assignments')
        .doc(assignmentId);

    await _firestore.runTransaction((transaction) async {
      final term = await transaction.get(termRef);
      final user = await transaction.get(userRef);
      final directory = await transaction.get(directoryRef);
      final assignment = await transaction.get(assignmentRef);

      if (!term.exists || term.data()?['active'] != true) {
        throw const CommitteeMemberAdminException(
          'The current committee must be imported before adding members.',
        );
      }
      if (assignment.exists) {
        throw const CommitteeMemberAdminException(
          'This member already has a committee assignment.',
        );
      }
      if (user.exists) {
        if (!directory.exists ||
            user.data()?['active'] != true ||
            directory.data()?['active'] != true ||
            user.data()?['phone'] != phone ||
            directory.data()?['phone'] != phone) {
          throw const CommitteeMemberAdminException(
            'Existing member data needs operator review.',
          );
        }
      } else {
        if (directory.exists) {
          throw const CommitteeMemberAdminException(
            'A directory entry already exists without a User.',
          );
        }
        final now = FieldValue.serverTimestamp();
        transaction.set(userRef, {
          'name': input.name.trim(),
          'phone': phone,
          'email': null,
          'blood_group': input.bloodGroup,
          'profession': input.profession?.trim(),
          'address': null,
          'photo_url': null,
          'access_role': 'committee',
          'active': true,
          'login_enabled': false,
          'preferred_language': null,
          'created_at': now,
          'created_by': actorUserId,
          'updated_at': now,
          'updated_by': actorUserId,
        });
        transaction.set(directoryRef, {
          'name': input.name.trim(),
          'phone': phone,
          'blood_group': input.bloodGroup,
          'profession': input.profession?.trim(),
          'photo_url': null,
          'active': true,
        });
      }
      transaction.set(assignmentRef, {
        'user_id': userId,
        'term_id': termId,
        'position': input.position.trim(),
        'active': true,
        'assigned_at': FieldValue.serverTimestamp(),
        'assigned_by': actorUserId,
        'ended_at': null,
      });
    });
  }
}
