import 'package:get/get.dart';
import '../models/auth_session.dart';
import '../models/profile_update.dart';
import '../models/user_model.dart';
import '../services/auth_services.dart';
import '../services/user_services.dart';
import '../views/main_navigation_screen.dart';
import '../views/login_screen.dart';

class AuthController extends GetxController {
  final AuthService _authService;
  final UserService _userService;

  AuthController({AuthService? authService, UserService? userService})
    : _authService = authService ?? AuthService(),
      _userService = userService ?? UserService();

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
      errorMessage.value = 'email_password_required'.tr;
      return;
    }

    if (!email.contains('@')) {
      errorMessage.value = 'valid_email_required'.tr;
      return;
    }

    if (password.length < 6) {
      errorMessage.value = 'password_min_length'.tr;
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
    try {
      await _authService.logout();
    } finally {
      // Local protected state must be cleared even when remote sign-out fails.
      currentUser.value = null;
      sessionState.value = AuthSessionState.unauthenticated;
      errorMessage.value = '';
      Get.offAll(() => const LoginScreen());
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    if (!email.contains('@')) {
      errorMessage.value = 'enter_email'.tr;
      return false;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (_) {
      errorMessage.value = 'reset_failed'.tr;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateOwnProfile(ProfileUpdateInput input) async {
    final user = currentUser.value;
    if (user == null || sessionState.value != AuthSessionState.admitted) {
      errorMessage.value = 'session_unavailable'.tr;
      return false;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _userService.updateOwnProfile(userId: user.id, input: input);
      final refreshed = await _authService.resolveSession();
      _applySession(refreshed);
      if (!refreshed.isAdmitted) {
        errorMessage.value = _messageFor(refreshed);
        return false;
      }
      return true;
    } catch (_) {
      errorMessage.value = 'profile_update_error'.tr;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _applySession(AuthSessionResult result) {
    sessionState.value = result.state;
    currentUser.value = result.isAdmitted ? result.user : null;
  }

  String _messageFor(AuthSessionResult result) {
    switch (result.state) {
      case AuthSessionState.emailUnverified:
        return 'email_unverified'.tr;
      case AuthSessionState.unlinked:
        return 'account_unlinked'.tr;
      case AuthSessionState.linkInactive:
        return 'link_inactive'.tr;
      case AuthSessionState.userMissing:
        return 'user_missing'.tr;
      case AuthSessionState.userInactive:
        return 'user_inactive'.tr;
      case AuthSessionState.loginDisabled:
        return 'login_disabled'.tr;
      case AuthSessionState.invalidRole:
        return 'invalid_role'.tr;
      case AuthSessionState.error:
        return _authService.authErrorCode(result.error).tr;
      case AuthSessionState.unauthenticated:
        return 'login_failed'.tr;
      case AuthSessionState.admitted:
        return '';
    }
  }
}
