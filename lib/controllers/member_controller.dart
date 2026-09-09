import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/user_directory_model.dart';
import '../services/user_services.dart';

class MemberController extends GetxController {
  final UserService _userService;

  MemberController({UserService? userService})
    : _userService = userService ?? UserService();

  final RxBool isLoading = false.obs;
  final RxList<UserDirectoryModel> members = <UserDirectoryModel>[].obs;

  Future<void> loadMembers() async {
    try {
      isLoading.value = true;
      members.value = await _userService.getActiveDirectory();
    } catch (error) {
      Get.snackbar(
        'Directory unavailable',
        'The active member directory could not be loaded: $error',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
