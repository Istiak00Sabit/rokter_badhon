import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/donation_model.dart';
import '../services/donation_service.dart';

class DonationController extends GetxController {
  final DonationService service;
  DonationController({DonationService? service})
    : service = service ?? DonationService();

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final errorCode = ''.obs;
  final pageErrorCode = ''.obs;
  final donations = <DonationModel>[].obs;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  Future<void> loadHistory() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorCode.value = '';
    pageErrorCode.value = '';
    hasMore.value = false;
    _cursor = null;
    donations.clear();
    try {
      final page = await service.getHistoryPage();
      donations.assignAll(page.items);
      _cursor = page.cursor;
      hasMore.value = page.hasMore;
    } on DonationDataException {
      errorCode.value = 'malformed_data';
    } on DonationServiceException catch (error) {
      errorCode.value = error.code;
    } catch (_) {
      errorCode.value = 'operation_failed';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value ||
        !hasMore.value || _cursor == null) return;
    isLoadingMore.value = true;
    pageErrorCode.value = '';
    try {
      final page = await service.getHistoryPage(after: _cursor);
      donations.addAll(page.items);
      _cursor = page.cursor;
      hasMore.value = page.hasMore;
    } on DonationDataException {
      pageErrorCode.value = 'malformed_data';
    } on DonationServiceException catch (error) {
      pageErrorCode.value = error.code;
    } catch (_) {
      pageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMore.value = false;
    }
  }
}
