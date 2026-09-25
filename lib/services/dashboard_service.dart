import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/notice_model.dart';

class DashboardServiceException implements Exception {
  final String code;
  final String? message;
  const DashboardServiceException(this.code, {this.message});
}

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
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getTotalDonors', error);
      throw DashboardServiceException(error.code, message: error.message);
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
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getTotalMembers', error);
      throw DashboardServiceException(error.code, message: error.message);
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
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getThisMonthDonations', error);
      throw DashboardServiceException(error.code, message: error.message);
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
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getActiveRequests', error);
      throw DashboardServiceException(error.code, message: error.message);
    }
  }

  // =========================================================
  // LATEST NOTICES
  // =========================================================

  Future<List<NoticeModel>> getLatestNotices() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.noticesCollection)
          .where('status', isEqualTo: 'published')
          .orderBy('created_at', descending: true)
          .limit(3)
          .get();

      return snapshot.docs
          .map((doc) => NoticeModel.fromMap(doc.data(), doc.id))
          .toList(growable: false);
    } on NoticeDataException catch (error) {
      debugPrint(
        '[DashboardService] getLatestNotices failed: '
        'NoticeDataException(message: ${error.message})',
      );
      throw DashboardServiceException('malformed_data', message: error.message);
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getLatestNotices', error);
      throw DashboardServiceException(error.code, message: error.message);
    }
  }
}

void _logFirebaseFailure(String query, FirebaseException error) {
  debugPrint(
    '[DashboardService] $query failed: '
    'FirebaseException(code: ${error.code}, message: ${error.message})',
  );
}
