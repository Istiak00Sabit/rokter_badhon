import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final AuthController authController =
        Get.find<AuthController>();

    return Scaffold(
      backgroundColor:
          AppColors.background,

      appBar: AppBar(
        title:
            const Text(
          'প্রোফাইল',
        ),

        backgroundColor:
            AppColors.primary,

        foregroundColor:
            AppColors.white,

        centerTitle:
            true,

        automaticallyImplyLeading:
            false,
      ),

      body:
          Obx(
        () {
          final user =
              authController
                  .currentUser
                  .value;

          if (user == null) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color:
                    AppColors.primary,
              ),
            );
          }

          return SingleChildScrollView(
            child:
                Column(
              children: [
                // =============================================
                // HEADER
                // =============================================

                Container(
                  width:
                      double.infinity,

                  decoration:
                      const BoxDecoration(
                    color:
                        AppColors.primary,

                    borderRadius:
                        BorderRadius.only(
                      bottomLeft:
                          Radius.circular(
                        30,
                      ),

                      bottomRight:
                          Radius.circular(
                        30,
                      ),
                    ),
                  ),

                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    30,
                  ),

                  child:
                      Column(
                    children: [
                      Container(
                        width:
                            90,

                        height:
                            90,

                        decoration:
                            BoxDecoration(
                          color: AppColors.white
                              .withValues(
                            alpha:
                                0.2,
                          ),

                          shape:
                              BoxShape.circle,

                          border:
                              Border.all(
                            color:
                                AppColors.white,

                            width:
                                2,
                          ),
                        ),

                        child:
                            Center(
                          child:
                              Text(
                            user.name.isNotEmpty
                                ? user.name[0]
                                    .toUpperCase()
                                : 'A',

                            style:
                                const TextStyle(
                              fontSize:
                                  36,

                              fontWeight:
                                  FontWeight.bold,

                              color:
                                  AppColors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      Text(
                        user.name,

                        style:
                            const TextStyle(
                          fontSize:
                              22,

                          fontWeight:
                              FontWeight.bold,

                          color:
                              AppColors.white,
                        ),
                      ),

                      const SizedBox(
                        height:
                            4,
                      ),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal:
                              12,

                          vertical:
                              4,
                        ),

                        decoration:
                            BoxDecoration(
                          color: AppColors.white
                              .withValues(
                            alpha:
                                0.2,
                          ),

                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),

                        child:
                            Text(
                          AppConstants.roleLabel(
                            user.role,
                          ),

                          style:
                              const TextStyle(
                            color:
                                AppColors.white,

                            fontSize:
                                13,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height:
                      20,
                ),

                // =============================================
                // DETAILS
                // =============================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        16,
                  ),

                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      _sectionTitle(
                        'ব্যক্তিগত তথ্য',
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _buildInfoCard(
                        [
                          if (user.email
                              .isNotEmpty)
                            _buildInfoRow(
                              Icons.email_outlined,
                              'ইমেইল',
                              user.email,
                            ),

                          if (user.phone
                              .isNotEmpty)
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'ফোন',
                              user.phone,
                            ),

                          if (user.bloodGroup
                              .isNotEmpty)
                            _buildInfoRow(
                              Icons
                                  .water_drop_outlined,
                              'রক্তের গ্রুপ',
                              user.bloodGroup,
                            ),

                          if (user.address
                              .isNotEmpty)
                            _buildInfoRow(
                              Icons
                                  .location_on_outlined,
                              'ঠিকানা',
                              user.address,
                            ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      _sectionTitle(
                        'অ্যাকাউন্টের তথ্য',
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _buildInfoCard(
                        [
                          _buildInfoRow(
                            Icons.badge_outlined,
                            'ভূমিকা',
                            AppConstants.roleLabel(
                              user.role,
                            ),
                          ),

                          if (user.role !=
                              AppConstants.roleAdmin)
                            _buildInfoRow(
                              Icons.groups_outlined,
                              'কমিটির বছর',
                              '${user.committeeYear}',
                            ),

                          _buildInfoRow(
                            Icons
                                .calendar_today_outlined,
                            'যোগদানের তারিখ',
                            '${user.joinedDate.day}/'
                            '${user.joinedDate.month}/'
                            '${user.joinedDate.year}',
                          ),

                          _buildInfoRow(
                            Icons
                                .check_circle_outline,
                            'অ্যাকাউন্ট স্ট্যাটাস',
                            user.active
                                ? 'সক্রিয়'
                                : 'নিষ্ক্রিয়',

                            valueColor:
                                user.active
                                    ? AppColors.success
                                    : AppColors.error,
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            24,
                      ),

                      // =======================================
                      // LOGOUT
                      // =======================================

                      SizedBox(
                        width:
                            double.infinity,

                        height:
                            52,

                        child:
                            OutlinedButton.icon(
                          onPressed:
                              () {
                            Get.dialog(
                              AlertDialog(
                                title:
                                    const Text(
                                  'লগআউট',
                                ),

                                content:
                                    const Text(
                                  'আপনি কি লগআউট করতে চান?',
                                ),

                                actions:
                                    [
                                  TextButton(
                                    onPressed:
                                        () =>
                                            Get.back(),

                                    child:
                                        const Text(
                                      'না',
                                    ),
                                  ),

                                  TextButton(
                                    onPressed:
                                        () =>
                                            authController.logout(),

                                    child:
                                        const Text(
                                      'হ্যাঁ',

                                      style:
                                          TextStyle(
                                        color:
                                            AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },

                          icon:
                              const Icon(
                            Icons.logout,

                            color:
                                AppColors.primary,
                          ),

                          label:
                              const Text(
                            'লগআউট',

                            style:
                                TextStyle(
                              color:
                                  AppColors.primary,

                              fontSize:
                                  16,

                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          style:
                              OutlinedButton.styleFrom(
                            side:
                                const BorderSide(
                              color:
                                  AppColors.primary,
                            ),

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            30,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
          width:
              4,

          height:
              18,

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
          width:
              8,
        ),

        Text(
          title,

          style:
              const TextStyle(
            fontSize:
                16,

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
  // INFO CARD
  // =========================================================

  Widget _buildInfoCard(
    List<Widget> children,
  ) {
    if (children.isEmpty) {
      return const SizedBox();
    }

    return Container(
      decoration:
          BoxDecoration(
        color:
            AppColors.white,

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        boxShadow:
            [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  0.05,
            ),

            blurRadius:
                8,

            offset:
                const Offset(
              0,
              2,
            ),
          ),
        ],
      ),

      child:
          Column(
        children:
            children
                .asMap()
                .entries
                .map(
          (
            entry,
          ) {
            return Column(
              children: [
                entry.value,

                if (entry.key <
                    children.length - 1)
                  const Divider(
                    height:
                        1,

                    indent:
                        16,

                    endIndent:
                        16,
                  ),
              ],
            );
          },
        ).toList(),
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
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            16,

        vertical:
            14,
      ),

      child:
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
                14,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  label,

                  style:
                      const TextStyle(
                    fontSize:
                        12,

                    color:
                        AppColors.textGrey,
                  ),
                ),

                const SizedBox(
                  height:
                      2,
                ),

                Text(
                  value,

                  style:
                      TextStyle(
                    fontSize:
                        14,

                    fontWeight:
                        FontWeight.w500,

                    color:
                        valueColor ??
                            AppColors.textDark,
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