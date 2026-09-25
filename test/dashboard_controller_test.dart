import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/controllers/dashboard_controller.dart';
import 'package:rokter_badhon/models/notice_model.dart';
import 'package:rokter_badhon/models/user_model.dart';
import 'package:rokter_badhon/services/dashboard_service.dart';

void main() {
  test('a failed dashboard query does not hide successful sections', () async {
    final service = _FakeDashboardService();
    final controller = DashboardController(
      dashboardService: service,
      currentUserLoader: () async => _executiveUser,
    );

    await controller.loadDashboard();

    expect(controller.totalDonorsError.value?.code, 'permission-denied');
    expect(controller.totalDonorsError.value?.message, 'donors denied');
    expect(controller.totalMembers.value, 12);
    expect(controller.thisMonthDonations.value, 3);
    expect(controller.activeRequests.value, 2);
    expect(controller.notices, isEmpty);
    expect(controller.noticesError.value, isNull);
    expect(service.calls, 5);
    expect(controller.isLoading.value, isFalse);
  });

  test(
    'a failed notices section preserves statistics and exposes its error',
    () async {
      final service = _FakeDashboardService(failNotices: true);
      final controller = DashboardController(
        dashboardService: service,
        currentUserLoader: () async => _executiveUser,
      );

      await controller.loadDashboard();

      expect(controller.notices, isEmpty);
      expect(controller.noticesError.value?.code, 'malformed_data');
      expect(
        controller.noticesError.value?.message,
        'notice data is malformed',
      );
      expect(controller.totalDonors.value, 8);
      expect(controller.totalMembers.value, 12);
      expect(controller.thisMonthDonations.value, 3);
      expect(controller.activeRequests.value, 2);
      expect(service.calls, 5);
    },
  );
}

final _executiveUser = UserModel(
  id: 'user-1',
  name: 'Executive',
  phone: '0000000000',
  email: null,
  bloodGroup: null,
  profession: null,
  address: null,
  photoUrl: null,
  accessRole: 'executive',
  active: true,
  loginEnabled: true,
  preferredLanguage: null,
  createdAt: DateTime.utc(2026),
  createdBy: null,
  updatedAt: DateTime.utc(2026),
  updatedBy: null,
);

class _FakeDashboardService implements DashboardService {
  _FakeDashboardService({this.failNotices = false});

  final bool failNotices;
  int calls = 0;

  @override
  Future<int> getTotalDonors() async {
    calls++;
    if (failNotices) return 8;
    throw const DashboardServiceException(
      'permission-denied',
      message: 'donors denied',
    );
  }

  @override
  Future<int> getTotalMembers() async {
    calls++;
    return 12;
  }

  @override
  Future<int> getThisMonthDonations() async {
    calls++;
    return 3;
  }

  @override
  Future<int> getActiveRequests() async {
    calls++;
    return 2;
  }

  @override
  Future<List<NoticeModel>> getLatestNotices() async {
    calls++;
    if (failNotices) {
      throw const DashboardServiceException(
        'malformed_data',
        message: 'notice data is malformed',
      );
    }
    return const [];
  }
}
