import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/donor_model.dart';
import '../services/donor_service.dart';

class DonorController extends GetxController {
  final DonorService _donorService = DonorService();

  // Form fields
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final villageController = TextEditingController();

  // Dropdowns
  final RxString selectedBloodGroup = ''.obs;
  final RxString selectedGender = ''.obs;
  final RxString selectedUnion = ''.obs;

  // Last donation date
  final Rx<DateTime?> lastDonatedDate = Rx<DateTime?>(null);

  // Loading
  final RxBool isLoading = false.obs;

  // Donors list
  final RxList<DonorModel> donors = <DonorModel>[].obs;

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    villageController.dispose();
    super.onClose();
  }

  void clearForm() {
    nameController.clear();
    phoneController.clear();
    villageController.clear();
    selectedBloodGroup.value = '';
    selectedGender.value = '';
    selectedUnion.value = '';
    lastDonatedDate.value = null;
  }

  Future<void> addDonor() async {
    // Validation
    if (nameController.text.trim().isEmpty) {
      Get.snackbar('ত্রুটি', 'নাম দিন!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      Get.snackbar('ত্রুটি', 'ফোন নম্বর দিন!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (selectedBloodGroup.value.isEmpty) {
      Get.snackbar('ত্রুটি', 'রক্তের গ্রুপ বেছে নিন!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (selectedGender.value.isEmpty) {
      Get.snackbar('ত্রুটি', 'লিঙ্গ বেছে নিন!',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      isLoading.value = true;

      final donor = DonorModel(
        id: '',
        name: nameController.text.trim(),
        bloodGroup: selectedBloodGroup.value,
        gender: selectedGender.value,
        phone: phoneController.text.trim(),
        village: villageController.text.trim(),
        union: selectedUnion.value,
        lastDonated: lastDonatedDate.value,
      );

      final result = await _donorService.addDonor(donor);

      if (result['success']) {
        clearForm();
        Get.back(); // Close the form
        Get.snackbar(
          'সফল!',
          result['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar('ত্রুটি', result['message'],
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadDonors() async {
    isLoading.value = true;
    donors.value = await _donorService.getAllDonors();
    isLoading.value = false;
  }
}