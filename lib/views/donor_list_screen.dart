import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/donor_controller.dart';
import '../models/donor_model.dart';
import 'add_donor_screen.dart';

class DonorListScreen extends StatelessWidget {
  const DonorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DonorController controller = Get.put(DonorController());
    final RxString searchQuery = ''.obs;
    final RxString selectedFilter = 'সব'.obs;
    final searchController = TextEditingController();

    // Load donors when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadDonors();
    });

    final List<String> filters = ['সব', ...AppConstants.bloodGroups];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('রক্তদাতা তালিকা'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Obx(() => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${controller.donors.length} জন',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter section
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: searchController,
                  onChanged: (val) => searchQuery.value = val.trim(),
                  decoration: InputDecoration(
                    hintText: 'নাম বা ফোন দিয়ে খুঁজুন...',
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.primary, size: 20),
                    suffixIcon: Obx(() => searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textGrey, size: 18),
                            onPressed: () {
                              searchController.clear();
                              searchQuery.value = '';
                            },
                          )
                        : const SizedBox()),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Blood group filter chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      return Obx(() {
                        final isSelected = selectedFilter.value == filter;
                        return GestureDetector(
                          onTap: () => selectedFilter.value = filter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textLight,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textGrey,
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Donor list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              // Apply search + filter
              final filtered = controller.donors.where((donor) {
                final matchesSearch = searchQuery.value.isEmpty ||
                    donor.name
                        .toLowerCase()
                        .contains(searchQuery.value.toLowerCase()) ||
                    donor.phone.contains(searchQuery.value);
                final matchesFilter = selectedFilter.value == 'সব' ||
                    donor.bloodGroup == selectedFilter.value;
                return matchesSearch && matchesFilter;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          size: 64,
                          color: AppColors.textLight),
                      const SizedBox(height: 16),
                      const Text(
                        'কোনো রক্তদাতা পাওয়া যায়নি',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'নতুন রক্তদাতা যোগ করুন',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: controller.loadDonors,
                color: AppColors.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildDonorCard(filtered[index]);
                  },
                ),
              );
            }),
          ),
        ],
      ),

      // FAB to add donor
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Get.to(() => const AddDonorScreen());
          // Reload list after returning from add screen
          controller.loadDonors();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: AppColors.white),
        label: const Text(
          'নতুন রক্তদাতা',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDonorCard(DonorModel donor) {
    final bool eligible = donor.isEligible;

    return Container(
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
            // Blood group badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Center(
                child: Text(
                  donor.bloodGroup,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Donor info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          donor.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      // Eligible badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: eligible
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          eligible ? '✓ দিতে পারবেন' : '⏳ অপেক্ষা',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: eligible
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        donor.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                      if (donor.gender.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Text(
                          donor.gender,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (donor.union.isNotEmpty || donor.village.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (donor.village.isNotEmpty) donor.village,
                              if (donor.union.isNotEmpty) donor.union,
                            ].join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (donor.lastDonated != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Text(
                          'শেষ দান: ${donor.lastDonated!.day}/${donor.lastDonated!.month}/${donor.lastDonated!.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Call icon
            IconButton(
              onPressed: () {
                // TODO: launch phone call
                Get.snackbar(
                  'ফোন করুন',
                  donor.phone,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.primary,
                  colorText: AppColors.white,
                  duration: const Duration(seconds: 2),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call,
                    color: AppColors.primary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}