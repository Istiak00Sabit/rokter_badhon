import 'package:get/get.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';
import '../services/auth_services.dart';
import '../views/main_navigation_screen.dart';
import '../views/login_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService;

  AuthController({AuthService? authService})
    : _authService = authService ?? AuthService();

  // Loading state
  final RxBool isLoading = false.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  // Current user data
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final Rx<AuthSessionState> sessionState =
      AuthSessionState.unauthenticated.obs;

  Future<AuthSessionResult> restoreSession() async {
    final result = await _authService.resolveSession();
    _applySession(result);
    return result;
  }

  // Login function
  Future<void> login({required String email, required String password}) async {
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

      final result = await _authService.login(email: email, password: password);

      _applySession(result);
      if (result.isAdmitted) {
        // সফল হলে MainNavigation এ যাও
        Get.offAll(() => const MainNavigationScreen());
      } else {
        errorMessage.value = _messageFor(result);
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

  void _applySession(AuthSessionResult result) {
    sessionState.value = result.state;
    currentUser.value = result.isAdmitted ? result.user : null;
  }

  String _messageFor(AuthSessionResult result) {
    switch (result.state) {
      case AuthSessionState.emailUnverified:
        return 'আপনার ইমেইল যাচাই করুন।';
      case AuthSessionState.unlinked:
        return 'এই অ্যাকাউন্টটি এখনো সংগঠনের ব্যবহারকারীর সাথে যুক্ত নয়।';
      case AuthSessionState.linkInactive:
        return 'আপনার অ্যাকাউন্টের সংযোগ নিষ্ক্রিয়।';
      case AuthSessionState.userMissing:
        return 'সংযুক্ত ব্যবহারকারীর প্রোফাইল পাওয়া যায়নি।';
      case AuthSessionState.userInactive:
        return 'আপনার অ্যাকাউন্ট নিষ্ক্রিয় করা হয়েছে।';
      case AuthSessionState.loginDisabled:
        return 'এই অ্যাকাউন্টে লগইন বন্ধ করা হয়েছে।';
      case AuthSessionState.invalidRole:
        return 'এই অ্যাকাউন্টের অনুমোদিত ভূমিকা নেই।';
      case AuthSessionState.error:
        return _authService.authErrorMessage(result.error);
      case AuthSessionState.unauthenticated:
        return 'লগইন করা যায়নি।';
      case AuthSessionState.admitted:
        return '';
    }
  }
}
