import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
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

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  static final List<Widget> _screens = [
    const DashboardScreen(),
    const DonorListScreen(),
    const BloodRequestScreen(),
    const CommitteeScreen(),
    const ProfileScreen(),
  ];

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
