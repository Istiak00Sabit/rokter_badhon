import 'package:get/get.dart';
import '../services/dashboard_service.dart';
import '../services/auth_services.dart';
import '../models/user_model.dart';
import '../models/notice_model.dart';

class DashboardController extends GetxController {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();

  // Stats
  final RxInt totalDonors = 0.obs;
  final RxInt totalMembers = 0.obs;
  final RxInt thisMonthDonations = 0.obs;
  final RxInt activeRequests = 0.obs;

  // Notices
  final RxList<NoticeModel> notices = <NoticeModel>[].obs;

  // Current user
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  // Loading
  final RxBool isLoading = true.obs;
  final RxString errorCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      isLoading.value = true;
      errorCode.value = '';

      // Current user data আনো
      currentUser.value = await _authService.getCurrentUserData();

      // সব data একসাথে আনো
      final results = await Future.wait([
        _dashboardService.getTotalDonors(),
        _dashboardService.getTotalMembers(),
        _canViewDonationHistory(currentUser.value?.accessRole)
            ? _dashboardService.getThisMonthDonations()
            : Future.value(0),
        _dashboardService.getActiveRequests(),
        _dashboardService.getLatestNotices(),
      ]);

      totalDonors.value = results[0] as int;
      totalMembers.value = results[1] as int;
      thisMonthDonations.value = results[2] as int;
      activeRequests.value = results[3] as int;
      notices.assignAll(results[4] as List<NoticeModel>);
    } on DashboardServiceException catch (error) {
      errorCode.value = error.code;
    } catch (_) {
      errorCode.value = 'unexpected';
    } finally {
      isLoading.value = false;
    }
  }

  // Refresh করো
  @override
  Future<void> refresh() async {
    await loadDashboard();
  }
}

bool _canViewDonationHistory(String? role) =>
    role == 'developer_admin' || role == 'leader' || role == 'executive';
