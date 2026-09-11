import 'package:get/get.dart';

import '../models/donation_model.dart';
import '../services/donation_service.dart';

class DonationController extends GetxController {
  final DonationService service;
  DonationController({DonationService? service})
    : service = service ?? DonationService();
  final isLoading = false.obs;
  final errorCode = ''.obs;
  final donations = <DonationModel>[].obs;

  Future<void> loadHistory() async {
    isLoading.value = true;
    errorCode.value = '';
    try {
      donations.assignAll(await service.getHistory());
    } on DonationDataException {
      donations.clear();
      errorCode.value = 'malformed_data';
    } on DonationServiceException catch (error) {
      donations.clear();
      errorCode.value = error.code;
    } finally {
      isLoading.value = false;
    }
  }
}
