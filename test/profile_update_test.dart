import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/profile_update.dart';
import 'package:rokter_badhon/models/user_directory_model.dart';
import 'package:rokter_badhon/models/user_model.dart';
import 'package:rokter_badhon/services/user_services.dart';

void main() {
  final time = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
  final user = UserModel.fromMap({
    'name': 'User',
    'phone': '00000000000',
    'email': 'private@example.test',
    'blood_group': null,
    'profession': null,
    'address': null,
    'photo_url': 'https://example.test/photo.jpg',
    'access_role': 'member',
    'active': true,
    'login_enabled': true,
    'preferred_language': null,
    'created_at': time,
    'created_by': null,
    'updated_at': time,
    'updated_by': null,
  }, 'user-id');

  test('profile update input accepts only the six approved fields', () {
    final valid = {
      'name': 'Updated',
      'phone': '11111111111',
      'blood_group': 'A+',
      'profession': 'Teacher',
      'address': 'Address',
      'preferred_language': 'bn',
    };
    expect(ProfileUpdateInput.fromMap(valid).toMap().keys, ProfileUpdateInput.editableFields);

    for (final field in [
      'photo_url',
      'access_role',
      'active',
      'login_enabled',
      'created_at',
      'created_by',
      'updated_at',
      'updated_by',
      'auth_uid',
      'position',
    ]) {
      expect(
        () => ProfileUpdateInput.fromMap({...valid, field: 'forbidden'}),
        throwsFormatException,
      );
    }
  });

  test('missing or mismatched directory projection fails safely', () {
    expect(
      () => UserService.validateExistingProjection(user, null),
      throwsA(isA<ProfileUpdateException>()),
    );
    final malformedProjection = UserDirectoryModel.fromMap({
      'name': 'Different',
      'phone': user.phone,
      'blood_group': user.bloodGroup,
      'profession': user.profession,
      'photo_url': user.photoUrl,
      'active': user.active,
    }, user.id);
    expect(
      () => UserService.validateExistingProjection(user, malformedProjection),
      throwsA(isA<ProfileUpdateException>()),
    );
  });

  test('normal service logic uses active directory and has no User creation path', () {
    final service = File('lib/services/user_services.dart').readAsStringSync();
    final controller = File('lib/controllers/member_controller.dart').readAsStringSync();
    expect(service, contains(".collection(directoryCollection)"));
    expect(service, contains(".where(directoryActiveField, isEqualTo: true)"));
    expect(service, isNot(contains('Future<Map<String, dynamic>> addUser')));
    expect(service, isNot(contains('.set(')));
    expect(controller, isNot(contains('selectedRole')));
    expect(controller, isNot(contains('addMember')));
  });
}
