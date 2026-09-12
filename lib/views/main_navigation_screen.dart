import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_session.dart';
import 'committee_screen.dart';
import 'blood_request_screen.dart';
import 'dashboard_screen.dart';
import 'donor_list_screen.dart';
import 'profile_screen.dart';

class NavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changePage(int index) {
    currentIndex.value = index;
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  bool _refreshingSession = false;

  static final List<Widget> _screens = [
    const DashboardScreen(),
    const DonorListScreen(),
    const BloodRequestScreen(),
    const CommitteeScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProtectedSession();
    }
  }

  Future<void> _refreshProtectedSession() async {
    if (_refreshingSession || !Get.isRegistered<AuthController>()) return;
    _refreshingSession = true;
    final controller = Get.find<AuthController>();
    final previousRole = controller.currentUser.value?.accessRole;
    try {
      final refreshed = await controller.restoreSession();
      if (!mounted) return;
      if (ProtectedSessionPolicy.requiresReauthentication(
        previousRole: previousRole,
        refreshed: refreshed,
      )) {
        try {
          await controller.logout();
        } catch (_) {
          // logout() clears local protected state in finally; an unavailable
          // remote sign-out must not surface as an unhandled lifecycle error.
        }
      }
    } finally {
      _refreshingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final NavigationController navController = Get.put(NavigationController());

    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: navController.currentIndex.value,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textGrey,
          backgroundColor: AppColors.white,
          elevation: 8,
          currentIndex: navController.currentIndex.value,
          onTap: navController.changePage,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: 'home'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.water_drop_outlined),
              activeIcon: const Icon(Icons.water_drop),
              label: 'donors'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.emergency_outlined),
              activeIcon: const Icon(Icons.emergency),
              label: 'requests'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.groups_outlined),
              activeIcon: const Icon(Icons.groups),
              label: 'committee'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: 'profile'.tr,
            ),
          ],
        ),
      ),
    );
  }
}
