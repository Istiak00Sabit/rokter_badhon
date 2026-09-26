import 'package:get/get.dart';

import '../data/ghatail_village_data.dart';

class AppConstants {
  // Blood groups
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // Gender
  static const List<String> genders = ['male', 'female', 'other'];

  static String genderLabel(String gender) => switch (gender) {
    'male' => 'gender.male'.tr,
    'female' => 'gender.female'.tr,
    'other' => 'gender.other'.tr,
    _ => 'unknown'.tr,
  };

  // =========================================================
  // USER ROLES
  // =========================================================

  static const String roleDeveloperAdmin = 'developer_admin';
  static const String roleLeader = 'leader';
  static const String roleExecutive = 'executive';
  static const String roleCommittee = 'committee';
  static const String roleMember = 'member';
  static const Set<String> roles = {
    roleDeveloperAdmin,
    roleLeader,
    roleExecutive,
    roleCommittee,
    roleMember,
  };

  static String roleLabel(String role) =>
      roles.contains(role) ? 'role.$role'.tr : 'unknown'.tr;

  static String positionLabel(String position) {
    final translated = 'position.$position'.tr;
    return translated == 'position.$position'
        ? position.replaceAll('_', ' ')
        : translated;
  }

  // Firestore collections
  static const String donorsCollection = 'donors';
  static const String donorSubmissionsCollection = 'donor_submissions';
  static const String donationsCollection = 'donations';
  static const String bloodRequestsCollection = 'blood_requests';
  static const String noticesCollection = 'notices';

  // Address
  static const String upazila = 'ঘাটাইল';
  static const String district = 'টাঙ্গাইল';

  static List<String> get unions => GhatailVillageData.unions;

  static List<String> villagesForUnion(String union) =>
      GhatailVillageData.villagesForUnion(union);

}
