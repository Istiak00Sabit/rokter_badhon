class AppConstants {
  // Blood groups
  static const List<String> bloodGroups = [
    'A+', 'A-',
    'B+', 'B-',
    'AB+', 'AB-',
    'O+', 'O-',
  ];

  // Gender
  static const List<String> genders = [
    'পুরুষ',
    'মহিলা',
    'অন্যান্য',
  ];

  // =========================================================
  // USER ROLES
  // =========================================================

  // Developer/System admin - শুধুমাত্র তোমার account
  static const String roleAdmin = 'admin';

  // Organization roles
  static const String rolePresident = 'president';
  static const String roleVP = 'vp';
  static const String roleGS = 'gs';
  static const String roleAssistantGS = 'assistant_gs';
  static const String roleTreasurer = 'treasurer';
  static const String roleOrganizingSecretary = 'organizing_secretary';
  static const String roleCommittee = 'committee';
  static const String roleMember = 'member';

  // Admin এখানে intentionally নেই
  static const List<String> assignableRoles = [
    rolePresident,
    roleVP,
    roleGS,
    roleAssistantGS,
    roleTreasurer,
    roleOrganizingSecretary,
    roleCommittee,
    roleMember,
  ];

  static String roleLabel(String role) {
    switch (role) {
      case roleAdmin:
        return 'ডেভেলপার অ্যাডমিন';
      case rolePresident:
        return 'সভাপতি';
      case roleVP:
        return 'সহ-সভাপতি';
      case roleGS:
        return 'সাধারণ সম্পাদক';
      case roleAssistantGS:
        return 'সহ-সাধারণ সম্পাদক';
      case roleTreasurer:
        return 'কোষাধ্যক্ষ';
      case roleOrganizingSecretary:
        return 'সাংগঠনিক সম্পাদক';
      case roleCommittee:
        return 'কার্যনির্বাহী সদস্য';
      case roleMember:
      default:
        return 'সাধারণ সদস্য';
    }
  }

  // Donation eligibility
  static const int eligibilityDays = 90;

  // Firestore collections
  static const String usersCollection = 'users';
  static const String donorsCollection = 'donors';
  static const String donationsCollection = 'donations';
  static const String requestsCollection = 'requests';
  static const String noticesCollection = 'notices';

  // Address
  static const String upazilla = 'ঘাটাইল';
  static const String district = 'টাঙ্গাইল';

  static const List<String> unions = [
    'ঘাটাইল পৌরসভা',
    'দিঘলকান্দি',
    'লোকেরপাড়',
    'সংগ্রাম',
    'ধলাপাড়া',
    'আনেহলা',
    'দেওপাড়া',
    'রসুলপুর',
    'জামুরকী',
    'পাকুটিয়া',
    'দিগড়',
  ];
}