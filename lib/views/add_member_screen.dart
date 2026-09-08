import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/member_controller.dart';

class AddMemberScreen extends StatelessWidget {
  const AddMemberScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final MemberController controller =
        Get.put(
      MemberController(),
    );

    return Scaffold(
      backgroundColor:
          AppColors.background,

      appBar: AppBar(
        title:
            const Text(
          'নতুন সদস্য যোগ করুন',
        ),

        backgroundColor:
            AppColors.primary,

        foregroundColor:
            AppColors.white,

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.white,
          ),

          onPressed: () {
            controller.clearForm();
            Get.back();
          },
        ),
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Text(
              'সদস্যের তথ্য যোগ হবে। অ্যাপে লগইন করার সুবিধা এখন চালু হবে না।',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            // =================================================
            // PERSONAL INFORMATION
            // =================================================

            _sectionTitle(
              'ব্যক্তিগত তথ্য',
            ),

            const SizedBox(
              height: 12,
            ),

            _buildTextField(
              controller:
                  controller.nameController,

              label:
                  'পূর্ণ নাম *',

              hint:
                  'সদস্যের নাম লিখুন',

              icon:
                  Icons.person_outline,
            ),

            const SizedBox(
              height: 14,
            ),

            _buildTextField(
              controller:
                  controller.phoneController,

              label:
                  'ফোন নম্বর *',

              hint:
                  '01XXXXXXXXX',

              icon:
                  Icons.phone_outlined,

              keyboardType:
                  TextInputType.phone,
            ),

            const SizedBox(
              height: 14,
            ),

            // Blood Group
            Obx(
              () => _buildDropdown(
                label:
                    'রক্তের গ্রুপ',

                icon:
                    Icons.water_drop_outlined,

                value: controller
                        .selectedBloodGroup
                        .value
                        .isEmpty
                    ? null
                    : controller
                        .selectedBloodGroup
                        .value,

                items:
                    AppConstants.bloodGroups,

                onChanged: (
                  value,
                ) {
                  if (value != null) {
                    controller
                        .selectedBloodGroup
                        .value = value;
                  }
                },
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            _buildTextField(
              controller:
                  controller.addressController,

              label:
                  'ঠিকানা',

              hint:
                  'সদস্যের ঠিকানা লিখুন',

              icon:
                  Icons.location_on_outlined,
            ),

            const SizedBox(
              height: 24,
            ),

            // =================================================
            // ROLE + COMMITTEE
            // =================================================

            _sectionTitle(
              'ভূমিকা ও কমিটি',
            ),

            const SizedBox(
              height: 12,
            ),

            Obx(
              () => _buildDropdown(
                label:
                    'ভূমিকা / পদ *',

                icon:
                    Icons.badge_outlined,

                value: controller
                        .selectedRole
                        .value
                        .isEmpty
                    ? null
                    : controller
                        .selectedRole
                        .value,

                items:
                    AppConstants.assignableRoles,

                itemLabelBuilder:
                    AppConstants.roleLabel,

                onChanged: (
                  value,
                ) {
                  if (value != null) {
                    controller
                        .selectedRole
                        .value = value;
                  }
                },
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // Committee year
            Obx(
              () => _buildDropdown(
                label:
                    'কমিটির বছর *',

                icon:
                    Icons.calendar_today_outlined,

                value:
                    '${controller.selectedYear.value}',

                items: controller
                    .availableYears
                    .map(
                      (year) => '$year',
                    )
                    .toList(),

                onChanged: (
                  value,
                ) {
                  if (value != null) {
                    controller
                            .selectedYear
                            .value =
                        int.parse(
                      value,
                    );
                  }
                },
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // Joining Date
            Obx(
              () => GestureDetector(
                onTap: () async {
                  final DateTime? picked =
                      await showDatePicker(
                    context: context,

                    initialDate:
                        controller
                            .joiningDate
                            .value,

                    firstDate:
                        DateTime(
                      2000,
                    ),

                    lastDate:
                        DateTime.now(),

                    builder: (
                      context,
                      child,
                    ) {
                      return Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(
                          colorScheme:
                              const ColorScheme
                                  .light(
                            primary:
                                AppColors.primary,
                          ),
                        ),

                        child: child!,
                      );
                    },
                  );

                  if (picked != null) {
                    controller
                        .joiningDate
                        .value = picked;
                  }
                },

                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.white,

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),

                    border:
                        Border.all(
                      color:
                          AppColors.textLight,
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .calendar_today_outlined,
                        color:
                            AppColors.primary,
                        size: 20,
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          const Text(
                            'যোগদানের তারিখ',

                            style:
                                TextStyle(
                              fontSize:
                                  12,

                              color:
                                  AppColors
                                      .textGrey,
                            ),
                          ),

                          const SizedBox(
                            height: 2,
                          ),

                          Text(
                            '${controller.joiningDate.value.day}/'
                            '${controller.joiningDate.value.month}/'
                            '${controller.joiningDate.value.year}',

                            style:
                                const TextStyle(
                              fontSize:
                                  15,

                              color:
                                  AppColors
                                      .textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 32,
            ),

            // =================================================
            // SUBMIT
            // =================================================

            Obx(
              () => SizedBox(
                width:
                    double.infinity,

                height:
                    52,

                child:
                    ElevatedButton(
                  onPressed: controller
                          .isLoading
                          .value
                      ? null
                      : controller
                          .addMember,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        AppColors.primary,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),

                  child: controller
                          .isLoading
                          .value
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            color:
                                AppColors.white,
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,

                          children: [
                            Icon(
                              Icons
                                  .person_add,
                              color:
                                  AppColors.white,
                            ),

                            SizedBox(
                              width: 8,
                            ),

                            Text(
                              'সদস্য যোগ করুন',

                              style:
                                  TextStyle(
                                fontSize:
                                    16,

                                fontWeight:
                                    FontWeight
                                        .bold,

                                color:
                                    AppColors
                                        .white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle(
    String title,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,

          decoration:
              BoxDecoration(
            color:
                AppColors.primary,

            borderRadius:
                BorderRadius.circular(
              2,
            ),
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          title,

          style:
              const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.bold,
            color:
                AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return TextField(
      controller:
          controller,

      keyboardType:
          keyboardType,

      decoration:
          InputDecoration(
        labelText:
            label,

        hintText:
            hint,

        prefixIcon:
            Icon(
          icon,
          color:
              AppColors.primary,
          size:
              20,
        ),

        filled:
            true,

        fillColor:
            AppColors.white,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),

          borderSide:
              const BorderSide(
            color:
                AppColors.textLight,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),

          borderSide:
              const BorderSide(
            color:
                AppColors.primary,

            width:
                2,
          ),
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal:
              16,

          vertical:
              14,
        ),
      ),
    );
  }

  // =========================================================
  // DROPDOWN
  // =========================================================

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?)
        onChanged,

    String Function(String)?
        itemLabelBuilder,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            16,

        vertical:
            4,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.white,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              AppColors.textLight,
        ),
      ),

      child:
          DropdownButtonHideUnderline(
        child:
            DropdownButton<String>(
          value:
              value,

          isExpanded:
              true,

          hint:
              Row(
            children: [
              Icon(
                icon,
                color:
                    AppColors.primary,
                size:
                    20,
              ),

              const SizedBox(
                width:
                    12,
              ),

              Text(
                label,

                style:
                    const TextStyle(
                  color:
                      AppColors.textGrey,
                ),
              ),
            ],
          ),

          icon:
              const Icon(
            Icons
                .keyboard_arrow_down,

            color:
                AppColors.textGrey,
          ),

          items:
              items.map(
            (
              item,
            ) {
              return DropdownMenuItem<
                  String>(
                value:
                    item,

                child:
                    Text(
                  itemLabelBuilder
                          ?.call(
                        item,
                      ) ??
                      item,
                ),
              );
            },
          ).toList(),

          onChanged:
              onChanged,
        ),
      ),
    );
  }
}
