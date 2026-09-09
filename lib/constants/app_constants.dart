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

  static const String roleDeveloperAdmin = 'developer_admin';
  static const String roleLeader = 'leader';
  static const String roleExecutive = 'executive';
  static const String roleCommittee = 'committee';
  static const String roleMember = 'member';

  static String roleLabel(String role) {
    switch (role) {
      case roleDeveloperAdmin:
        return 'ডেভেলপার অ্যাডমিন';
      case roleLeader:
        return 'Leader';
      case roleExecutive:
        return 'Executive';
      case roleCommittee:
        return 'কার্যনির্বাহী সদস্য';
      case roleMember:
        return 'সাধারণ সদস্য';
      default:
        return 'Unavailable';
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
