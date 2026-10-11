import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/donor_controller.dart';
import '../models/donor_model.dart';
import '../localization/app_date_formatter.dart';
import 'add_donor_screen.dart';

class DonorListScreen extends StatefulWidget {
  const DonorListScreen({super.key});

  @override
  State<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  late final DonorController controller;
  final RxString searchQuery = ''.obs;
  final RxString selectedFilter = 'all'.obs;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<DonorController>()
        ? Get.find<DonorController>()
        : Get.put(DonorController());
    // Keep the visible filter synchronized when GetX reuses this controller
    // after navigating away and returning to the donor directory.
    selectedFilter.value = controller.directoryBloodGroup.value.isEmpty
        ? 'all'
        : controller.directoryBloodGroup.value;
    // A build/rebuild must never start new Firestore reads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.loadDonors();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchQuery.close();
    selectedFilter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> filters = ['all', ...AppConstants.bloodGroups];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('donors'.tr),
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
                    'donors_loaded_count'.trParams({
                      'count': '${controller.donors.length}',
                    }),
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
                  onSubmitted: controller.searchDirectory,
                  decoration: InputDecoration(
                    hintText: 'search_donors'.tr,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'donor_indexed_search'.tr,
                      icon: const Icon(Icons.manage_search,
                          color: AppColors.primary),
                      onPressed: () =>
                          controller.searchDirectory(searchController.text),
                    ),
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
                const SizedBox(height: 5),
                Obx(() => Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.indexedSearchTerm.value.isEmpty
                            ? 'donor_indexed_search_hint'.tr
                            : 'donor_indexed_search_active'.tr,
                        style: const TextStyle(
                          fontSize: 12, color: AppColors.textGrey),
                      ),
                    ),
                    if (controller.indexedSearchTerm.value.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          searchController.clear();
                          searchQuery.value = '';
                          controller.searchDirectory('');
                        },
                        child: Text('clear_search'.tr),
                      ),
                  ],
                )),
                const SizedBox(height: 10),

                // Blood group filter chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      return Obx(() {
                        final isSelected = selectedFilter.value == filter;
                        return GestureDetector(
                          onTap: () {
                            selectedFilter.value = filter;
                            controller.setDirectoryBloodGroup(
                              filter == 'all' ? null : filter,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
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
                              filter == 'all' ? 'all_blood_groups'.tr : filter,
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

              if (controller.errorCode.value.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text('donor_load_error'.tr),
                      TextButton(
                        onPressed: controller.loadDonors,
                        child: Text('retry'.tr),
                      ),
                    ],
                  ),
                );
              }

              // The exact indexed result must not be accidentally removed
              // by local substring filtering (+880 versus 01 or case differences).
              final serverSearchIsCurrent =
                  controller.indexedSearchTerm.value.isNotEmpty &&
                  searchQuery.value == controller.indexedSearchTerm.value;
              final filtered = controller.donors.where((donor) {
                if (serverSearchIsCurrent) return true;
                return searchQuery.value.isEmpty ||
                    donor.name.toLowerCase().contains(
                      searchQuery.value.toLowerCase(),
                    ) ||
                    donor.phone.contains(searchQuery.value);
              }).toList();

              if (filtered.isEmpty &&
                  !controller.hasMoreDonors.value &&
                  controller.pageErrorCode.value.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        size: 64,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.value.isNotEmpty
                            ? 'donor_no_matches_loaded'.tr
                            : 'no_donors'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'add_donor'.tr,
                        style: const TextStyle(
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
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  children: [
                    if (searchQuery.value.isNotEmpty ||
                        controller.hasMoreDonors.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          controller.hasMoreDonors.value
                              ? 'donor_search_partial'.tr
                              : 'donor_search_complete'.tr,
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'donor_no_matches_loaded'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...filtered.map((donor) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildDonorCard(donor, controller),
                        )),
                    if (controller.pageErrorCode.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'donor_page_error'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (controller.hasMoreDonors.value ||
                        controller.pageErrorCode.value.isNotEmpty)
                      Center(
                        child: controller.isLoadingMore.value
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                onPressed: controller.loadMoreDonors,
                                child: Text(
                                  controller.pageErrorCode.value.isNotEmpty
                                      ? 'retry'.tr
                                      : 'load_more'.tr,
                                ),
                              ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),

      // FAB to add donor
      floatingActionButton: controller.canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                controller.clearForm();
                await Get.to(() => const AddDonorScreen());
                // Reload list after returning from add screen
                controller.loadDonors();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add, color: AppColors.white),
              label: Text(
                'add_donor'.tr,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDonorCard(DonorModel donor, DonorController controller) {
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        donor.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                      if (donor.gender?.isNotEmpty ?? false) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppConstants.genderLabel(donor.gender!),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((donor.union?.isNotEmpty ?? false) ||
                      (donor.village?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (donor.village?.isNotEmpty ?? false)
                                donor.village!,
                              if (donor.union?.isNotEmpty ?? false)
                                donor.union!,
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
                  if (donor.lastDonatedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${'last_recorded_donation'.tr}: ${AppDateFormatter.short(donor.lastDonatedAt!)}',
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
            if (controller.canEdit)
              IconButton(
                tooltip: 'edit_donor'.tr,
                onPressed: () async {
                  controller.beginEdit(donor);
                  await Get.to(() => const AddDonorScreen());
                  controller.loadDonors();
                },
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              ),
            IconButton(
              onPressed: () {
                // Display the number without requesting device-call privileges.
                Get.snackbar(
                  'call'.tr,
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
                child: const Icon(
                  Icons.call,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
