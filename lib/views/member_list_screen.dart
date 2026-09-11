import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/member_controller.dart';
import '../models/user_directory_model.dart';

class MemberListScreen extends StatelessWidget {
  const MemberListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MemberController());
    final searchQuery = ''.obs;
    final searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.loadMembers(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('member_directory'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        centerTitle: true,
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${controller.members.length}')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (value) => searchQuery.value = value.trim(),
              decoration: InputDecoration(
                hintText: 'search_members'.tr,
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
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
                      Text('directory_error'.tr),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: controller.loadMembers,
                        child: Text('retry'.tr),
                      ),
                    ],
                  ),
                );
              }
              final query = searchQuery.value.toLowerCase();
              final filtered = controller.members.where((member) {
                if (query.isEmpty) return true;
                return member.name.toLowerCase().contains(query) ||
                    member.phone.toLowerCase().contains(query) ||
                    (member.profession?.toLowerCase().contains(query) ??
                        false) ||
                    (member.bloodGroup?.toLowerCase().contains(query) ?? false);
              }).toList();
              if (filtered.isEmpty) {
                return Center(child: Text('no_directory_entries'.tr));
              }
              return RefreshIndicator(
                onRefresh: controller.loadMembers,
                color: AppColors.primary,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, index) => _memberCard(filtered[index]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(UserDirectoryModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (member.phone.isNotEmpty) Text(member.phone),
                if (member.profession?.isNotEmpty == true)
                  Text(member.profession!),
                if (member.bloodGroup?.isNotEmpty == true)
                  Text('${'blood_group'.tr}: ${member.bloodGroup}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
