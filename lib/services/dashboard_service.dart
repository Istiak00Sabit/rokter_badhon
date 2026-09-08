import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

class DashboardService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // TOTAL DONORS
  // =========================================================

  Future<int> getTotalDonors() async {
    try {
      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _firestore
              .collection(
                AppConstants.donorsCollection,
              )
              .where(
                'active',
                isEqualTo: true,
              )
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
      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _firestore
              .collection(
                AppConstants.usersCollection,
              )
              .where(
                'active',
                isEqualTo: true,
              )
              .get();

      // Developer admin organization member count-এ আসবে না।
      final int total =
          snapshot.docs.where(
        (
          doc,
        ) {
          final Map<String, dynamic> data =
              doc.data();

          final String role =
              data['role']
                      ?.toString() ??
                  AppConstants.roleMember;

          return role !=
              AppConstants.roleAdmin;
        },
      ).length;

      return total;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================
  // THIS MONTH DONATIONS
  // =========================================================

  Future<int> getThisMonthDonations() async {
    try {
      final DateTime now =
          DateTime.now();

      final DateTime firstDay =
          DateTime(
        now.year,
        now.month,
        1,
      );

      final QuerySnapshot snapshot =
          await _firestore
              .collection(
                AppConstants
                    .donationsCollection,
              )
              .where(
                'date',
                isGreaterThanOrEqualTo:
                    firstDay
                        .toIso8601String(),
              )
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
      final QuerySnapshot snapshot =
          await _firestore
              .collection(
                AppConstants
                    .requestsCollection,
              )
              .where(
                'status',
                isEqualTo:
                    'active',
              )
              .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================
  // LATEST NOTICES
  // =========================================================

  Future<List<Map<String, dynamic>>>
      getLatestNotices() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection(
                AppConstants
                    .noticesCollection,
              )
              .orderBy(
                'date',
                descending:
                    true,
              )
              .limit(
                3,
              )
              .get();

      return snapshot.docs.map(
        (
          doc,
        ) {
          return {
            ...doc.data()
                as Map<String, dynamic>,

            'id':
                doc.id,
          };
        },
      ).toList();
    } catch (e) {
      return [];
    }
  }
}