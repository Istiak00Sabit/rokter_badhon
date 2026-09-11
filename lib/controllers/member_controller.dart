import 'package:get/get.dart';

import '../models/user_directory_model.dart';
import '../services/user_services.dart';

class MemberController extends GetxController {
  final UserService _userService;

  MemberController({UserService? userService})
    : _userService = userService ?? UserService();

  final RxBool isLoading = false.obs;
  final RxList<UserDirectoryModel> members = <UserDirectoryModel>[].obs;
  final RxString errorCode = ''.obs;

  Future<void> loadMembers() async {
    try {
      isLoading.value = true;
      errorCode.value = '';
      members.value = await _userService.getActiveDirectory();
    } catch (_) {
      errorCode.value = 'unavailable';
    } finally {
      isLoading.value = false;
    }
  }
}
