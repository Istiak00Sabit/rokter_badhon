import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../controllers/dashboard_controller.dart';
import '../models/notice_model.dart';
import '../views/add_donor_screen.dart';
import '../views/blood_request_screen.dart';
import '../views/donor_list_screen.dart';
import '../views/donation_history_screen.dart';
import '../views/event_list_screen.dart';
import '../views/member_list_screen.dart';
import '../views/notice_screen.dart';
import '../views/ranklist_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.put(DashboardController());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.primary,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(color: AppColors.primary),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'আসসালামুয়ালাইকুম,',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Obx(
                            () => Text(
                              controller.currentUser.value?.name ?? 'Admin',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.orgLocation,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary section title
                      const Text(
                        'সারসংক্ষেপ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stats grid - 2x2
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          // Total donors card
                          GestureDetector(
                            onTap: () => Get.to(() => const DonorListScreen()),
                            child: Obx(
                              () => _buildStatCard(
                                title: 'মোট রক্তদাতা',
                                value: '${controller.totalDonors.value}',
                                icon: Icons.water_drop,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          // Total members card
                          GestureDetector(
                            onTap: () => Get.to(() => const MemberListScreen()),
                            child: Obx(
                              () => _buildStatCard(
                                title: 'মোট সদস্য',
                                value: '${controller.totalMembers.value}',
                                icon: Icons.people,
                                color: const Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          // This month donations card
                          GestureDetector(
                            onTap: () => Get.snackbar(
                              'রক্তদানের তথ্য',
                              'এই মাসে মোট ${controller.thisMonthDonations.value} টি রক্তদান হয়েছে',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.primary,
                              colorText: AppColors.white,
                            ),
                            child: Obx(
                              () => _buildStatCard(
                                title: 'এই মাসে রক্তদান',
                                value: '${controller.thisMonthDonations.value}',
                                icon: Icons.favorite,
                                color: const Color(0xFF43A047),
                              ),
                            ),
                          ),
                          // Active requests card
                          GestureDetector(
                            onTap: () =>
                                Get.to(() => const BloodRequestScreen()),
                            child: Obx(
                              () => _buildStatCard(
                                title: 'জরুরি অনুরোধ',
                                value: '${controller.activeRequests.value}',
                                icon: Icons.emergency,
                                color: const Color(0xFFFB8C00),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Quick actions
                      const Text(
                        'দ্রুত অ্যাকশন',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              title: 'রক্তদাতা যোগ করুন',
                              icon: Icons.person_add,
                              onTap: () async {
                                await Get.to(() => const AddDonorScreen());
                                controller.refresh();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                _canViewDonationHistory(
                                  controller.currentUser.value?.accessRole,
                                )
                                ? _buildActionButton(
                                    title: 'রক্তদানের ইতিহাস',
                                    icon: Icons.history,
                                    onTap: () => Get.to(
                                      () => const DonationHistoryScreen(),
                                    ),
                                  )
                                : _buildActionButton(
                                    title: 'সদস্য তালিকা',
                                    icon: Icons.people_outline,
                                    onTap: () =>
                                        Get.to(() => const MemberListScreen()),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              title: 'র‍্যাংকলিস্ট',
                              icon: Icons.emoji_events,
                              onTap: () => Get.to(() => const RanklistScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              title: 'অনুষ্ঠান',
                              icon: Icons.event,
                              onTap: () =>
                                  Get.to(() => const EventListScreen()),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Notice board
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'নোটিশ বোর্ড',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Get.to(() => const NoticeScreen()),
                            child: const Text(
                              'সব দেখুন',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Notices list
                      Obx(
                        () => controller.notices.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.textLight,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'কোনো নোটিশ নেই',
                                    style: TextStyle(color: AppColors.textGrey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: controller.notices.length,
                                itemBuilder: (context, index) {
                                  final notice = controller.notices[index];
                                  return _buildNoticeCard(notice);
                                },
                              ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(NoticeModel notice) {
    return InkWell(
      onTap: () => Get.to(() => NoticeDetailScreen(notice: notice)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notice.important ? AppColors.primary : AppColors.textLight,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notice.important)
              const Icon(Icons.campaign, color: AppColors.primary, size: 20),
            if (notice.important) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canViewDonationHistory(String? role) =>
    role == 'developer_admin' || role == 'leader' || role == 'executive';
