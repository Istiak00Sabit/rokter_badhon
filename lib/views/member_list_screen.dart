import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/member_controller.dart';
import '../models/user_model.dart';
import 'add_member_screen.dart';

class MemberListScreen extends StatelessWidget {
  const MemberListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MemberController controller = Get.put(MemberController());

    final RxString searchQuery = ''.obs;

    final TextEditingController searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadMembers();
    });

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('সদস্য তালিকা'),

        backgroundColor: AppColors.primary,

        foregroundColor: AppColors.white,

        centerTitle: true,

        automaticallyImplyLeading: false,

        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 12),

              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Text(
                    '${controller.members.length} জন',

                    style: const TextStyle(
                      color: AppColors.white,

                      fontSize: 13,

                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ===================================================
          // SEARCH
          // ===================================================
          Container(
            color: AppColors.white,

            padding: const EdgeInsets.all(16),

            child: TextField(
              controller: searchController,

              onChanged: (value) {
                searchQuery.value = value.trim();
              },

              decoration: InputDecoration(
                hintText: 'নাম বা পদবী দিয়ে খুঁজুন...',

                prefixIcon: const Icon(
                  Icons.search,

                  color: AppColors.primary,

                  size: 20,
                ),

                suffixIcon: Obx(() {
                  if (searchQuery.value.isEmpty) {
                    return const SizedBox();
                  }

                  return IconButton(
                    icon: const Icon(
                      Icons.clear,

                      color: AppColors.textGrey,

                      size: 18,
                    ),

                    onPressed: () {
                      searchController.clear();

                      searchQuery.value = '';
                    },
                  );
                }),

                filled: true,

                fillColor: AppColors.background,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,

                  vertical: 12,
                ),
              ),
            ),
          ),

          // ===================================================
          // MEMBER LIST
          // ===================================================
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final String query = searchQuery.value.toLowerCase();

              final List<UserModel> filtered = controller.members.where((
                member,
              ) {
                if (query.isEmpty) {
                  return true;
                }

                final String roleLabel = AppConstants.roleLabel(
                  member.role,
                ).toLowerCase();

                return member.name.toLowerCase().contains(query) ||
                    member.phone.toLowerCase().contains(query) ||
                    roleLabel.contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.people_outline,

                        size: 64,

                        color: AppColors.textLight,
                      ),

                      SizedBox(height: 16),

                      Text(
                        'কোনো সদস্য পাওয়া যায়নি',

                        style: TextStyle(
                          fontSize: 16,

                          color: AppColors.textGrey,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        'নতুন সদস্য যোগ করুন',

                        style: TextStyle(
                          fontSize: 13,

                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // =============================================
              // GROUP BY COMMITTEE YEAR
              // =============================================

              final Map<int, List<UserModel>> groupedByYear = {};

              for (final UserModel member in filtered) {
                groupedByYear
                    .putIfAbsent(member.committeeYear, () => <UserModel>[])
                    .add(member);
              }

              final List<int> sortedYears = groupedByYear.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return RefreshIndicator(
                onRefresh: controller.loadMembers,

                color: AppColors.primary,

                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.all(16),

                  itemCount: sortedYears.length,

                  itemBuilder: (context, yearIndex) {
                    final int year = sortedYears[yearIndex];

                    final List<UserModel> yearMembers = groupedByYear[year]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 4),

                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,

                                  vertical: 4,
                                ),

                                decoration: BoxDecoration(
                                  color: AppColors.primary,

                                  borderRadius: BorderRadius.circular(20),
                                ),

                                child: Text(
                                  '$year সালের কমিটি',

                                  style: const TextStyle(
                                    color: AppColors.white,

                                    fontSize: 13,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              Text(
                                '(${yearMembers.length} জন)',

                                style: const TextStyle(
                                  fontSize: 12,

                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        ...yearMembers.map(
                          (member) => _buildMemberCard(member),
                        ),

                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),

      // =====================================================
      // ADD MEMBER
      // =====================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Get.to(() => const AddMemberScreen());

          await controller.loadMembers();
        },

        backgroundColor: AppColors.primary,

        icon: const Icon(Icons.person_add, color: AppColors.white),

        label: const Text(
          'নতুন সদস্য',

          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // =========================================================
  // MEMBER CARD
  // =========================================================

  Widget _buildMemberCard(UserModel member) {
    final String roleLabel = AppConstants.roleLabel(member.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: AppColors.white,

        borderRadius: BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),

            blurRadius: 8,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,

              height: 50,

              decoration: BoxDecoration(
                color: AppColors.primaryLight,

                shape: BoxShape.circle,

                border: Border.all(color: AppColors.primary, width: 1.5),
              ),

              child: Center(
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',

                  style: const TextStyle(
                    fontSize: 20,

                    fontWeight: FontWeight.bold,

                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    member.name,

                    style: const TextStyle(
                      fontSize: 15,

                      fontWeight: FontWeight.bold,

                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,

                      vertical: 3,
                    ),

                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Text(
                      roleLabel,

                      style: const TextStyle(
                        fontSize: 12,

                        color: AppColors.primaryDark,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Wrap(
                    spacing: 12,

                    runSpacing: 4,

                    children: [
                      if (member.phone.isNotEmpty)
                        _smallInfo(Icons.phone_outlined, member.phone),
                      _smallInfo(
                        Icons.login,
                        member.loginEnabled ? 'লগইন চালু' : 'লগইন চালু নয়',
                      ),

                      if (member.bloodGroup?.isNotEmpty == true)
                        _smallInfo(
                          Icons.water_drop_outlined,
                          member.bloodGroup!,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SMALL INFO
  // =========================================================

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Icon(icon, size: 14, color: AppColors.textGrey),

        const SizedBox(width: 4),

        Text(
          text,

          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }
}
