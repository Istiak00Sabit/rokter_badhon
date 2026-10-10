import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/notice_model.dart';

class DashboardServiceException implements Exception {
  final String code;
  final String? message;
  const DashboardServiceException(this.code, {this.message});
}

/// Firestore Timestamp boundaries for a calendar month in Bangladesh.
/// A fixed UTC+06:00 offset applies; Bangladesh does not use daylight saving.
class DhakaMonthWindow {
  final DateTime startUtc;
  final DateTime endUtc;

  const DhakaMonthWindow({required this.startUtc, required this.endUtc});

  factory DhakaMonthWindow.containing(DateTime instant) {
    final dhaka = instant.toUtc().add(const Duration(hours: 6));
    final start = DateTime.utc(dhaka.year, dhaka.month)
        .subtract(const Duration(hours: 6));
    final end = DateTime.utc(
      dhaka.month == 12 ? dhaka.year + 1 : dhaka.year,
      dhaka.month == 12 ? 1 : dhaka.month + 1,
    ).subtract(const Duration(hours: 6));
    return DhakaMonthWindow(startUtc: start, endUtc: end);
  }
}

class DashboardService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _utcNow;

  DashboardService({FirebaseFirestore? firestore, DateTime Function()? utcNow})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _utcNow = utcNow ?? DateTime.now;

  /// Aggregation counts avoid downloading every donor/member/donation/request
  /// document just to show four numbers on the dashboard. Count queries use
  /// the same field filters as the corresponding Firestore security rules.
  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final result = await query.count().get();
    final count = result.count;
    if (count == null || count < 0) {
      throw const DashboardServiceException('invalid_aggregation');
    }
    return count;
  }

  Future<int> getTotalDonors() async {
    try {
      return await _count(
        _firestore.collection(AppConstants.donorsCollection)
            .where('active', isEqualTo: true),
      );
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getTotalDonors', error);
      throw DashboardServiceException(error.code, message: error.message);
    }
  }

  Future<int> getTotalMembers() async {
    try {
      return await _count(
        _firestore.collection('user_directory')
            .where('active', isEqualTo: true),
      );
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getTotalMembers', error);
      throw DashboardServiceException(error.code, message: error.message);
    }
  }

  Future<int> getThisMonthDonations() async {
    try {
      final month = DhakaMonthWindow.containing(_utcNow());
      return await _count(
        _firestore.collection(AppConstants.donationsCollection)
            .where(
              'donation_date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(month.startUtc),
            )
            .where(
              'donation_date',
              isLessThan: Timestamp.fromDate(month.endUtc),
            ),
      );
    } on FirebaseException catch (error) {
      _logFirebaseFailure('getThisMonthDonations', error);
      throw DashboardServiceException(error.code, message: error.message);
    }
  }

  Future<int> getActiveRequests() async {
    try {
      return await _count(
        _firestore.collection(AppConstants.bloodRequestsCollection)
            .where('status', isEqualTo: 'active'),
      );
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
