import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/localization_controller.dart';
import '../localization/app_translations.dart';
import '../localization/app_date_formatter.dart';
import '../models/profile_update.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: Text('profile'.tr),

        backgroundColor: AppColors.primary,

        foregroundColor: AppColors.white,

        centerTitle: true,

        automaticallyImplyLeading: false,
      ),

      body: Obx(() {
        final user = authController.currentUser.value;

        if (user == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // =============================================
              // HEADER
              // =============================================
              Container(
                width: double.infinity,

                decoration: const BoxDecoration(
                  color: AppColors.primary,

                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),

                    bottomRight: Radius.circular(30),
                  ),
                ),

                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),

                child: Column(
                  children: [
                    Container(
                      width: 90,

                      height: 90,

                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),

                        shape: BoxShape.circle,

                        border: Border.all(color: AppColors.white, width: 2),
                      ),

                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'A',

                          style: const TextStyle(
                            fontSize: 36,

                            fontWeight: FontWeight.bold,

                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      user.name,

                      style: const TextStyle(
                        fontSize: 22,

                        fontWeight: FontWeight.bold,

                        color: AppColors.white,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,

                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        AppConstants.roleLabel(user.accessRole),

                        style: const TextStyle(
                          color: AppColors.white,

                          fontSize: 13,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =============================================
              // DETAILS
              // =============================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _sectionTitle('personal_info'.tr),

                    const SizedBox(height: 12),

                    _buildInfoCard([
                      if (user.email?.isNotEmpty == true)
                        _buildInfoRow(
                          Icons.email_outlined,
                          'email'.tr,
                          user.email!,
                        ),

                      if (user.phone.isNotEmpty)
                        _buildInfoRow(
                          Icons.phone_outlined,
                          'phone'.tr,
                          user.phone,
                        ),

                      if (user.bloodGroup?.isNotEmpty == true)
                        _buildInfoRow(
                          Icons.water_drop_outlined,
                          'blood_group'.tr,
                          user.bloodGroup!,
                        ),

                      if (user.address?.isNotEmpty == true)
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'address'.tr,
                          user.address!,
                        ),
                    ]),

                    const SizedBox(height: 16),

                    _sectionTitle('account_info'.tr),

                    const SizedBox(height: 12),

                    _buildInfoCard([
                      _buildInfoRow(
                        Icons.badge_outlined,
                        'role'.tr,
                        AppConstants.roleLabel(user.accessRole),
                      ),

                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'joined'.tr,
                        AppDateFormatter.short(user.createdAt),
                      ),

                      _buildInfoRow(
                        Icons.check_circle_outline,
                        'account_status'.tr,
                        user.active ? 'active'.tr : 'inactive'.tr,

                        valueColor: user.active
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _editProfile(context, authController, user),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text('edit_profile'.tr),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _languageSelector(),

                    const SizedBox(height: 12),

                    // =======================================
                    // LOGOUT
                    // =======================================
                    SizedBox(
                      width: double.infinity,

                      height: 52,

                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: Text('logout'.tr),

                              content: Text('logout_confirm'.tr),

                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),

                                  child: Text('no'.tr),
                                ),

                                TextButton(
                                  onPressed: () => authController.logout(),

                                  child: Text(
                                    'yes'.tr,

                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },

                        icon: const Icon(
                          Icons.logout,

                          color: AppColors.primary,
                        ),

                        label: Text(
                          'logout'.tr,

                          style: const TextStyle(
                            color: AppColors.primary,

                            fontSize: 16,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    AuthController controller,
    UserModel user,
  ) async {
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    final bloodGroup = TextEditingController(text: user.bloodGroup ?? '');
    final profession = TextEditingController(text: user.profession ?? '');
    final address = TextEditingController(text: user.address ?? '');
    final language = TextEditingController(text: user.preferredLanguage ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('edit_profile'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editField(name, 'name'.tr),
              _editField(phone, 'phone'.tr),
              _editField(bloodGroup, 'blood_group'.tr),
              _editField(profession, 'profession'.tr),
              _editField(address, 'address'.tr),
              _editField(language, 'preferred_language'.tr),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              final success = await controller.updateOwnProfile(
                ProfileUpdateInput(
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  bloodGroup: _nullableText(bloodGroup.text),
                  profession: _nullableText(profession.text),
                  address: _nullableText(address.text),
                  preferredLanguage: _nullableText(language.text),
                ),
              );
              if (success && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              } else if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(controller.errorMessage.value)),
                );
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  Widget _editField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _languageSelector() {
    final controller = Get.find<LocalizationController>();
    return Obx(
      () => SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: AppTranslations.bangla,
            label: Text('bangla'.tr),
          ),
          ButtonSegment(
            value: AppTranslations.english,
            label: Text('english'.tr),
          ),
        ],
        selected: {controller.locale.value.languageCode},
        onSelectionChanged: (values) => controller.setLanguage(values.single),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,

          height: 18,

          decoration: BoxDecoration(
            color: AppColors.primary,

            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(width: 8),

        Text(
          title,

          style: const TextStyle(
            fontSize: 16,

            fontWeight: FontWeight.bold,

            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // INFO CARD
  // =========================================================

  Widget _buildInfoCard(List<Widget> children) {
    if (children.isEmpty) {
      return const SizedBox();
    }

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

      child: Column(
        children: children.asMap().entries.map((entry) {
          return Column(
            children: [
              entry.value,

              if (entry.key < children.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  label,

                  style: const TextStyle(
                    fontSize: 12,

                    color: AppColors.textGrey,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 14,

                    fontWeight: FontWeight.w500,

                    color: valueColor ?? AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
