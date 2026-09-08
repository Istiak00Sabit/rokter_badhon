import 'package:get/get.dart';
import '../services/auth_services.dart';
import '../views/main_navigation_screen.dart';
import '../views/login_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  // Loading state
  final RxBool isLoading = false.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  // Current user data
  final Rx<dynamic> currentUser = Rx<dynamic>(null);

  @override
  void onInit() {
    super.onInit();
    // App start এ check করো user already login আছে কিনা
    _checkLoginStatus();
  }

  // Already login আছে কিনা check করো
  Future<void> _checkLoginStatus() async {
    if (_authService.isLoggedIn) {
      currentUser.value = await _authService.getCurrentUserData();
      if (currentUser.value == null) {
        await _authService.logout();
        return;
      }
      Get.offAll(() => const MainNavigationScreen());
    }
  }

  // Login function
  Future<void> login({
    required String email,
    required String password,
  }) async {
    // Validation
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'ইমেইল এবং পাসওয়ার্ড দিন!';
      return;
    }

    if (!email.contains('@')) {
      errorMessage.value = 'সঠিক ইমেইল ঠিকানা দিন!';
      return;
    }

    if (password.length < 6) {
      errorMessage.value = 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে!';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      Map<String, dynamic> result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success']) {
        currentUser.value = await _authService.getCurrentUserData();
        if (currentUser.value == null) {
          await _authService.logout();
          errorMessage.value = 'ব্যবহারকারীর লগইন অনুমতি যাচাই করা যায়নি!';
          return;
        }
        // সফল হলে MainNavigation এ যাও
        Get.offAll(() => const MainNavigationScreen());
      } else {
        errorMessage.value = result['message'];
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Logout function
  Future<void> logout() async {
    await _authService.logout();
    currentUser.value = null;
    Get.offAll(() => const LoginScreen());
  }
}
