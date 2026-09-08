import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/donor_controller.dart';

class AddDonorScreen extends StatelessWidget {
  const AddDonorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DonorController controller = Get.put(DonorController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('নতুন রক্তদাতা যোগ করুন'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () {
            controller.clearForm();
            Get.back();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'এখানে শুধুমাত্র রক্তদাতার তথ্য যোগ করুন। এটি অ্যাপ ব্যবহারকারী নয়।',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _sectionTitle('ব্যক্তিগত তথ্য'),
            const SizedBox(height: 12),

            // Name
            _buildTextField(
              controller: controller.nameController,
              label: 'পূর্ণ নাম *',
              hint: 'রক্তদাতার নাম লিখুন',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),

            // Phone
            _buildTextField(
              controller: controller.phoneController,
              label: 'ফোন নম্বর *',
              hint: '01XXXXXXXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Blood Group
            Obx(() => _buildDropdown(
                  label: 'রক্তের গ্রুপ *',
                  icon: Icons.water_drop_outlined,
                  value: controller.selectedBloodGroup.value.isEmpty
                      ? null
                      : controller.selectedBloodGroup.value,
                  items: AppConstants.bloodGroups,
                  onChanged: (val) => controller.selectedBloodGroup.value = val!,
                )),
            const SizedBox(height: 14),

            // Gender
            Obx(() => _buildDropdown(
                  label: 'লিঙ্গ *',
                  icon: Icons.wc_outlined,
                  value: controller.selectedGender.value.isEmpty
                      ? null
                      : controller.selectedGender.value,
                  items: AppConstants.genders,
                  onChanged: (val) => controller.selectedGender.value = val!,
                )),

            const SizedBox(height: 20),
            _sectionTitle('ঠিকানা'),
            const SizedBox(height: 12),

            // Village
            _buildTextField(
              controller: controller.villageController,
              label: 'গ্রাম',
              hint: 'গ্রামের নাম লিখুন',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 14),

            // Union
            Obx(() => _buildDropdown(
                  label: 'ইউনিয়ন / পৌরসভা',
                  icon: Icons.location_on_outlined,
                  value: controller.selectedUnion.value.isEmpty
                      ? null
                      : controller.selectedUnion.value,
                  items: AppConstants.unions,
                  onChanged: (val) => controller.selectedUnion.value = val!,
                )),
            const SizedBox(height: 14),

            // Upazilla & District (static - read only)
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(
                    label: 'উপজেলা',
                    value: AppConstants.upazilla,
                    icon: Icons.map_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadOnlyField(
                    label: 'জেলা',
                    value: AppConstants.district,
                    icon: Icons.location_city_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _sectionTitle('রক্তদানের তথ্য'),
            const SizedBox(height: 12),

            // Last donated date
            Obx(() => GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      controller.lastDonatedDate.value = picked;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'সর্বশেষ রক্তদানের তারিখ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                controller.lastDonatedDate.value == null
                                    ? 'তারিখ বেছে নিন (না থাকলে খালি রাখুন)'
                                    : '${controller.lastDonatedDate.value!.day}/${controller.lastDonatedDate.value!.month}/${controller.lastDonatedDate.value!.year}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: controller.lastDonatedDate.value == null
                                      ? AppColors.textGrey
                                      : AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.lastDonatedDate.value != null)
                          GestureDetector(
                            onTap: () => controller.lastDonatedDate.value = null,
                            child: const Icon(Icons.clear,
                                color: AppColors.textGrey, size: 18),
                          ),
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 32),

            // Submit button
            Obx(() => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.addDonor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add, color: AppColors.white),
                              SizedBox(width: 8),
                              Text(
                                'রক্তদাতা যোগ করুন',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                )),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: AppColors.textGrey)),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textGrey),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Row(
                      children: [
                        Icon(icon, color: AppColors.primary, size: 18),
                        const SizedBox(width: 12),
                        Text(item),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textGrey, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textGrey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}
