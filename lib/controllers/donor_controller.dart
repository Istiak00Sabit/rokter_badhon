import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../models/donor_model.dart';
import '../services/donor_service.dart';
import 'auth_controller.dart';

class DonorController extends GetxController {
  final DonorService _donorService;
  final AuthController _authController;

  DonorController({DonorService? donorService, AuthController? authController})
    : _donorService = donorService ?? DonorService(),
      _authController = authController ?? Get.find<AuthController>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final villageController = TextEditingController();
  final professionController = TextEditingController();
  final RxString selectedBloodGroup = ''.obs;
  final RxString selectedGender = ''.obs;
  final RxString selectedUnion = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorCode = ''.obs;
  final RxList<DonorModel> donors = <DonorModel>[].obs;
  final RxnString editingDonorId = RxnString();

  String? get _role => _authController.currentUser.value?.accessRole;
  bool get canCreate => {
    AppConstants.roleDeveloperAdmin,
    AppConstants.roleLeader,
    AppConstants.roleExecutive,
    AppConstants.roleCommittee,
  }.contains(_role);
  bool get canEdit => {
    AppConstants.roleDeveloperAdmin,
    AppConstants.roleLeader,
    AppConstants.roleExecutive,
  }.contains(_role);

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    villageController.dispose();
    professionController.dispose();
    super.onClose();
  }

  void clearForm() {
    nameController.clear();
    phoneController.clear();
    villageController.clear();
    professionController.clear();
    selectedBloodGroup.value = '';
    selectedGender.value = '';
    selectedUnion.value = '';
    editingDonorId.value = null;
  }

  void beginEdit(DonorModel donor) {
    if (!canEdit) {
      _showError('permission_denied');
      return;
    }
    editingDonorId.value = donor.id;
    nameController.text = donor.name;
    phoneController.text = donor.phone;
    villageController.text = donor.village ?? '';
    professionController.text = donor.profession ?? '';
    selectedBloodGroup.value = donor.bloodGroup;
    selectedGender.value = donor.gender ?? '';
    selectedUnion.value = donor.union ?? '';
  }

  DonorInput _input() => DonorInput(
    name: nameController.text,
    phone: phoneController.text,
    bloodGroup: selectedBloodGroup.value,
    gender: selectedGender.value.isEmpty ? null : selectedGender.value,
    village: villageController.text.trim().isEmpty
        ? null
        : villageController.text,
    union: selectedUnion.value.isEmpty ? null : selectedUnion.value,
    upazila: AppConstants.upazila,
    district: AppConstants.district,
    profession: professionController.text.trim().isEmpty
        ? null
        : professionController.text,
  );

  Future<void> addDonor() async {
    final actor = _authController.currentUser.value;
    if (!canCreate || actor == null) {
      _showError('permission_denied');
      return;
    }
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        selectedBloodGroup.value.isEmpty) {
      _showError('invalid_input');
      return;
    }
    try {
      isLoading.value = true;
      errorCode.value = '';
      await _donorService.addDonor(input: _input(), actorUserId: actor.id);
      clearForm();
      Get.back();
      Get.snackbar(
        'success'.tr,
        'donor_added'.tr,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on DonorDataException {
      _showError('invalid_input');
    } on DonorServiceException catch (error) {
      _showError(error.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveDonor() async {
    final donorId = editingDonorId.value;
    if (donorId == null) {
      await addDonor();
      return;
    }
    final actor = _authController.currentUser.value;
    if (!canEdit || actor == null) {
      _showError('permission_denied');
      return;
    }
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        selectedBloodGroup.value.isEmpty) {
      _showError('invalid_input');
      return;
    }
    try {
      isLoading.value = true;
      errorCode.value = '';
      await _donorService.editDonor(
        donorId: donorId,
        input: _input(),
        actorUserId: actor.id,
      );
      clearForm();
      Get.back();
      Get.snackbar(
        'success'.tr,
        'donor_updated'.tr,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on DonorDataException {
      _showError('invalid_input');
    } on DonorServiceException catch (error) {
      _showError(error.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadDonors() async {
    try {
      isLoading.value = true;
      errorCode.value = '';
      donors.assignAll(await _donorService.getAllDonors());
    } on DonorDataException {
      donors.clear();
      errorCode.value = 'malformed_data';
    } on DonorServiceException catch (error) {
      donors.clear();
      errorCode.value = error.code;
    } finally {
      isLoading.value = false;
    }
  }

  void _showError(String code) {
    errorCode.value = code;
    Get.snackbar(
      'error'.tr,
      (const {
            'permission_denied',
            'invalid_input',
            'network_unavailable',
            'query_unavailable',
            'malformed_data',
          }.contains(code)
          ? code
          : 'operation_failed').tr,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}
