import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../data/ghatail_village_data.dart';
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
  final RxBool locationsReady = false.obs;
  final RxBool locationLoadFailed = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorCode = ''.obs;
  final RxList<DonorModel> donors = <DonorModel>[].obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreDonors = false.obs;
  final RxString pageErrorCode = ''.obs;
  final RxString directoryBloodGroup = ''.obs;
  final RxString indexedSearchTerm = ''.obs;
  DocumentSnapshot<Map<String, dynamic>>? _directoryCursor;
  int _directoryGeneration = 0;
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
  void onInit() {
    super.onInit();
    _loadLocations();
  }

  Future<void> retryLocations() => _loadLocations();

  Future<void> _loadLocations() async {
    try {
      await GhatailVillageData.load();
      locationsReady.value = true;
      locationLoadFailed.value = false;
    } catch (_) {
      locationLoadFailed.value = true;
    }
  }

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
        selectedBloodGroup.value.isEmpty ||
        selectedUnion.value.isEmpty ||
        villageController.text.trim().isEmpty) {
      _showError('invalid_input');
      return;
    }
    try {
      isLoading.value = true;
      errorCode.value = '';
      await _donorService.submitDonor(
        input: _input(),
        actorUserId: actor.id,
        actorRole: actor.accessRole,
      );
      clearForm();
      Get.back();
      Get.snackbar(
        'success'.tr,
        'donor_submitted'.tr,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on DonorDataException {
      _showError('invalid_input');
    } on DonorServiceException catch (error) {
      _showError(error.code);
    } catch (_) {
      _showError('operation_failed');
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
        selectedBloodGroup.value.isEmpty ||
        selectedUnion.value.isEmpty ||
        villageController.text.trim().isEmpty) {
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
    } catch (_) {
      _showError('operation_failed');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchDirectory(String term) async {
    final normalized = term.trim();
    if (indexedSearchTerm.value == normalized) {
      await loadDonors();
      return;
    }
    indexedSearchTerm.value = normalized;
    await loadDonors();
  }

  Future<void> setDirectoryBloodGroup(String? bloodGroup) async {
    final value = bloodGroup ?? '';
    if (directoryBloodGroup.value == value) return;
    directoryBloodGroup.value = value;
    await loadDonors();
  }

  Future<void> loadDonors() async {
    final generation = ++_directoryGeneration;
    isLoading.value = true;
    isLoadingMore.value = false;
    errorCode.value = '';
    pageErrorCode.value = '';
    hasMoreDonors.value = false;
    _directoryCursor = null;
    donors.clear();
    final filter = directoryBloodGroup.value;
    try {
      final term = indexedSearchTerm.value;
      final page = term.isEmpty
          ? await _donorService.getActiveDonorsPage(
              bloodGroup: filter.isEmpty ? null : filter,
            )
          : await _donorService.searchActiveDonorsPage(
              search: term,
              bloodGroup: filter.isEmpty ? null : filter,
            );
      if (generation != _directoryGeneration) return;
      donors.assignAll(page.items);
      _directoryCursor = page.cursor;
      hasMoreDonors.value = page.hasMore;
    } on DonorDataException {
      if (generation == _directoryGeneration) {
        errorCode.value = 'malformed_data';
      }
    } on DonorServiceException catch (error) {
      if (generation == _directoryGeneration) errorCode.value = error.code;
    } catch (_) {
      if (generation == _directoryGeneration) {
        errorCode.value = 'operation_failed';
      }
    } finally {
      if (generation == _directoryGeneration) isLoading.value = false;
    }
  }

  Future<void> loadMoreDonors() async {
    if (isLoading.value || isLoadingMore.value || !hasMoreDonors.value ||
        _directoryCursor == null) {
      return;
    }
    final generation = _directoryGeneration;
    final cursor = _directoryCursor;
    final filter = directoryBloodGroup.value;
    isLoadingMore.value = true;
    pageErrorCode.value = '';
    try {
      final term = indexedSearchTerm.value;
      final page = term.isEmpty
          ? await _donorService.getActiveDonorsPage(
              bloodGroup: filter.isEmpty ? null : filter,
              after: cursor,
            )
          : await _donorService.searchActiveDonorsPage(
              search: term,
              bloodGroup: filter.isEmpty ? null : filter,
              after: cursor,
            );
      if (generation != _directoryGeneration) return;
      final existing = donors.map((value) => value.id).toSet();
      donors.addAll(page.items.where((value) => existing.add(value.id)));
      _directoryCursor = page.cursor;
      hasMoreDonors.value = page.hasMore;
    } on DonorDataException {
      if (generation == _directoryGeneration) {
        pageErrorCode.value = 'malformed_data';
      }
    } on DonorServiceException catch (error) {
      if (generation == _directoryGeneration) pageErrorCode.value = error.code;
    } catch (_) {
      if (generation == _directoryGeneration) {
        pageErrorCode.value = 'operation_failed';
      }
    } finally {
      if (generation == _directoryGeneration) isLoadingMore.value = false;
    }
  }

  void _showError(String code) {
    errorCode.value = code;
    Get.snackbar(
      'error'.tr,
      (const {
                'permission_denied',
                'committee_assignment_required',
                'invalid_input',
                'network_unavailable',
                'query_unavailable',
                'malformed_data',
                'duplicate_donor',
              }.contains(code)
              ? code
              : 'operation_failed')
          .tr,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}
