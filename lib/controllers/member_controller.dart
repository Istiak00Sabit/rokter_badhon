import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';
import '../services/user_services.dart';

class MemberController extends GetxController {
  final UserService _userService = UserService();

  // =========================================================
  // FORM CONTROLLERS
  // =========================================================

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController addressController =
      TextEditingController();

  // =========================================================
  // FORM VALUES
  // =========================================================

  final RxString selectedBloodGroup = ''.obs;

  // President / VP / GS / Committee / Member etc.
  final RxString selectedRole = ''.obs;

  final RxInt selectedYear =
      DateTime.now().year.obs;

  final Rx<DateTime> joiningDate =
      DateTime.now().obs;

  // =========================================================
  // STATE
  // =========================================================

  final RxBool isLoading = false.obs;

  // Screen-এর নাম Member হলেও
  // data entity এখন UserModel।
  final RxList<UserModel> members =
      <UserModel>[].obs;

  // =========================================================
  // AVAILABLE COMMITTEE YEARS
  // =========================================================

  List<int> get availableYears {
    final int current =
        DateTime.now().year;

    return List.generate(
      6,
      (index) => current - index,
    );
  }

  // =========================================================
  // CLEAR FORM
  // =========================================================

  void clearForm() {
    nameController.clear();
    phoneController.clear();
    addressController.clear();

    selectedBloodGroup.value = '';
    selectedRole.value = '';

    selectedYear.value =
        DateTime.now().year;

    joiningDate.value =
        DateTime.now();
  }

  // =========================================================
  // VALIDATION
  // =========================================================

  bool _validateForm() {
    if (nameController.text.trim().isEmpty) {
      Get.snackbar(
        'ত্রুটি',
        'সদস্যের নাম দিন!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }

    if (phoneController.text.trim().isEmpty) {
      Get.snackbar(
        'ত্রুটি',
        'ফোন নম্বর দিন!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }

    if (selectedRole.value.isEmpty) {
      Get.snackbar(
        'ত্রুটি',
        'সদস্যের ভূমিকা / পদ বেছে নিন!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }

    return true;
  }

  // =========================================================
  // ADD MEMBER
  // =========================================================

  Future<void> addMember() async {
    if (!_validateForm()) {
      return;
    }

    try {
      isLoading.value = true;

      final UserModel user = UserModel(
        id: '',
        authUid: null,
        loginEnabled: false,

        name: nameController.text.trim(),

        // এই stage-এ শুধুমাত্র organization user record
        // তৈরি হচ্ছে।
        //
        // Login account পরে activate করা হবে।
        email: '',

        role: selectedRole.value,

        phone:
            phoneController.text.trim(),

        bloodGroup:
            selectedBloodGroup.value,

        address:
            addressController.text.trim(),

        committeeYear:
            selectedYear.value,

        joinedDate:
            joiningDate.value,

        active: true,
      );

      final Map<String, dynamic> result =
          await _userService.addUser(
        user,
      );

      if (result['success'] == true) {
        clearForm();

        // Member List refresh
        await loadMembers();

        Get.back();

        Get.snackbar(
          'সফল!',
          result['message'] ??
              'সদস্য যোগ করা হয়েছে!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition:
              SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'ত্রুটি',
          result['message'] ??
              'সদস্য যোগ করা যায়নি!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'ত্রুটি',
        'সদস্য যোগ করতে সমস্যা হয়েছে: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // LOAD MEMBERS
  // =========================================================

  Future<void> loadMembers() async {
    try {
      isLoading.value = true;

      members.value =
          await _userService
              .getOrganizationUsers();
    } catch (e) {
      Get.snackbar(
        'ত্রুটি',
        'সদস্য তালিকা আনতে সমস্যা হয়েছে: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================
  // CLEAN UP
  // =========================================================

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    super.onClose();
  }
}
