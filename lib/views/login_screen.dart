import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController());
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final RxBool obscurePassword = true.obs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top red section
              Container(
                width: double.infinity,
                height: 280,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        size: 50,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      AppStrings.orgLocation,
                      style: TextStyle(fontSize: 14, color: AppColors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              AutofillGroup(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'লগইন করুন',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'আপনার অ্যাকাউন্টে প্রবেশ করুন',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Email field
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: AppStrings.email,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: AppColors.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      Obx(
                        () => TextField(
                          controller: passwordController,
                          obscureText: obscurePassword.value,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: AppStrings.password,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textGrey,
                              ),
                              onPressed: () {
                                obscurePassword.value = !obscurePassword.value;
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            AppStrings.forgotPassword,
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Error message
                      Obx(
                        () => authController.errorMessage.value.isNotEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  authController.errorMessage.value,
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : const SizedBox(),
                      ),

                      const SizedBox(height: 16),

                      // Login button
                      Obx(
                        () => SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: authController.isLoading.value
                                ? null
                                : () {
                                    authController.login(
                                      email: emailController.text,
                                      password: passwordController.text,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authController.isLoading.value
                                ? const CircularProgressIndicator(
                                    color: AppColors.white,
                                  )
                                : const Text(
                                    AppStrings.login,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Footer
                      Center(
                        child: Text(
                          '© ${AppStrings.orgName} ${DateTime.now().year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
