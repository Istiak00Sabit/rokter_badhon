import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../services/dashboard_service.dart';
import '../services/auth_services.dart';
import '../models/user_model.dart';
import '../models/notice_model.dart';

typedef CurrentUserLoader = Future<UserModel?> Function();

class DashboardSectionError {
  final String code;
  final String? message;

  const DashboardSectionError(this.code, this.message);
}

class DashboardController extends GetxController {
  final DashboardService _dashboardService;
  final CurrentUserLoader _currentUserLoader;

  DashboardController({
    DashboardService? dashboardService,
    CurrentUserLoader? currentUserLoader,
  }) : _dashboardService = dashboardService ?? DashboardService(),
       _currentUserLoader =
           currentUserLoader ?? AuthService().getCurrentUserData;

  // Stats
  final RxInt totalDonors = 0.obs;
  final RxInt totalMembers = 0.obs;
  final RxInt thisMonthDonations = 0.obs;
  final RxInt activeRequests = 0.obs;

  final RxBool isTotalDonorsLoading = true.obs;
  final RxBool isTotalMembersLoading = true.obs;
  final RxBool isThisMonthDonationsLoading = true.obs;
  final RxBool isActiveRequestsLoading = true.obs;

  final Rxn<DashboardSectionError> totalDonorsError =
      Rxn<DashboardSectionError>();
  final Rxn<DashboardSectionError> totalMembersError =
      Rxn<DashboardSectionError>();
  final Rxn<DashboardSectionError> thisMonthDonationsError =
      Rxn<DashboardSectionError>();
  final Rxn<DashboardSectionError> activeRequestsError =
      Rxn<DashboardSectionError>();

  // Notices
  final RxList<NoticeModel> notices = <NoticeModel>[].obs;
  final RxBool isNoticesLoading = true.obs;
  final Rxn<DashboardSectionError> noticesError = Rxn<DashboardSectionError>();

  // Current user
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  // Loading
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    final currentUserFuture = _loadCurrentUser();

    try {
      await Future.wait<void>([
        _loadSection<int>(
          name: 'totalDonors',
          loading: isTotalDonorsLoading,
          error: totalDonorsError,
          load: _dashboardService.getTotalDonors,
          onSuccess: (value) => totalDonors.value = value,
        ),
        _loadSection<int>(
          name: 'totalMembers',
          loading: isTotalMembersLoading,
          error: totalMembersError,
          load: _dashboardService.getTotalMembers,
          onSuccess: (value) => totalMembers.value = value,
        ),
        _loadSection<int>(
          name: 'thisMonthDonations',
          loading: isThisMonthDonationsLoading,
          error: thisMonthDonationsError,
          load: () async {
            final user = await currentUserFuture;
            if (user.error != null) {
              throw DashboardServiceException(
                user.error!.code,
                message: user.error!.message,
              );
            }
            if (user.user == null) {
              throw const DashboardServiceException('session_unavailable');
            }
            if (!_canViewDonationHistory(user.user!.accessRole)) {
              // A read denied by the user's role must never appear as a
              // legitimate zero-donation month.
              throw const DashboardServiceException('not_authorized');
            }
            return _dashboardService.getThisMonthDonations();
          },
          onSuccess: (value) => thisMonthDonations.value = value,
        ),
        _loadSection<int>(
          name: 'activeRequests',
          loading: isActiveRequestsLoading,
          error: activeRequestsError,
          load: _dashboardService.getActiveRequests,
          onSuccess: (value) => activeRequests.value = value,
        ),
        _loadSection<List<NoticeModel>>(
          name: 'notices',
          loading: isNoticesLoading,
          error: noticesError,
          load: _dashboardService.getLatestNotices,
          onSuccess: notices.assignAll,
        ),
      ]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<({UserModel? user, DashboardSectionError? error})>
  _loadCurrentUser() async {
    // Refresh must not retain an earlier user's name or permissions.
    currentUser.value = null;
    try {
      final user = await _currentUserLoader();
      currentUser.value = user;
      if (user == null || !user.active || !user.loginEnabled ||
          !user.hasRecognizedAccessRole) {
        return (
          user: null,
          error: const DashboardSectionError('session_unavailable', null),
        );
      }
      return (user: user, error: null);
    } catch (error, stackTrace) {
      debugPrint(
        '[DashboardController] getCurrentUserData failed: $error\n$stackTrace',
      );
      return (
        user: null,
        error: const DashboardSectionError('user_context_unavailable', null),
      );
    }
  }

  Future<void> _loadSection<T>({
    required String name,
    required RxBool loading,
    required Rxn<DashboardSectionError> error,
    required Future<T> Function() load,
    required void Function(T) onSuccess,
  }) async {
    loading.value = true;
    error.value = null;
    try {
      onSuccess(await load());
    } on DashboardServiceException catch (exception) {
      error.value = DashboardSectionError(exception.code, exception.message);
    } catch (exception, stackTrace) {
      debugPrint('[DashboardController] $name failed: $exception\n$stackTrace');
      error.value = DashboardSectionError('unexpected', '$exception');
    } finally {
      loading.value = false;
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
