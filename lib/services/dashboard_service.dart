import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

class DashboardService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _utcNow;

  DashboardService({FirebaseFirestore? firestore, DateTime Function()? utcNow})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _utcNow = utcNow ?? DateTime.now;

  // =========================================================
  // TOTAL DONORS
  // =========================================================

  Future<int> getTotalDonors() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================
  // TOTAL ORGANIZATION MEMBERS
  // =========================================================

  Future<int> getTotalMembers() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('user_directory')
          .where('active', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================
  // THIS MONTH DONATIONS
  // =========================================================

  Future<int> getThisMonthDonations() async {
    try {
      final nowDhaka = _utcNow().toUtc().add(const Duration(hours: 6));
      final firstDayUtc = DateTime.utc(
        nowDhaka.year,
        nowDhaka.month,
      ).subtract(const Duration(hours: 6));
      final nextMonthUtc = DateTime.utc(
        nowDhaka.month == 12 ? nowDhaka.year + 1 : nowDhaka.year,
        nowDhaka.month == 12 ? 1 : nowDhaka.month + 1,
      ).subtract(const Duration(hours: 6));

      final QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.donationsCollection)
          .where(
            'donation_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayUtc),
          )
          .where('donation_date', isLessThan: Timestamp.fromDate(nextMonthUtc))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================
  // ACTIVE BLOOD REQUESTS
  // =========================================================

  Future<int> getActiveRequests() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.bloodRequestsCollection)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================
  // LATEST NOTICES
  // =========================================================

  Future<List<Map<String, dynamic>>> getLatestNotices() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.noticesCollection)
          .orderBy('date', descending: true)
          .limit(3)
          .get();

      return snapshot.docs.map((doc) {
        return {...doc.data() as Map<String, dynamic>, 'id': doc.id};
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
