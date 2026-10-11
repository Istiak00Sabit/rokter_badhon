import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'auth_controller.dart';

class EventController extends GetxController {
  final EventService service;
  final AuthController authController;

  EventController({EventService? service, AuthController? authController})
    : service = service ?? EventService(),
      authController = authController ?? Get.find<AuthController>();

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMoreActive = false.obs;
  final RxBool isLoadingMoreHidden = false.obs;
  final RxBool activeHasMore = false.obs;
  final RxBool hiddenHasMore = false.obs;
  final RxString errorCode = ''.obs;
  final RxString activePageErrorCode = ''.obs;
  final RxString hiddenPageErrorCode = ''.obs;
  final RxList<EventModel> activeEvents = <EventModel>[].obs;
  final RxList<EventModel> hiddenEvents = <EventModel>[].obs;
  DocumentSnapshot<Map<String, dynamic>>? _activeCursor;
  DocumentSnapshot<Map<String, dynamic>>? _hiddenCursor;

  bool get canReviewHidden => {
    AppConstants.roleDeveloperAdmin,
    AppConstants.roleLeader,
  }.contains(authController.currentUser.value?.accessRole);

  Future<void> loadEvents() async {
    if (isLoading.value || isLoadingMoreActive.value ||
        isLoadingMoreHidden.value) {
      return;
    }
    isLoading.value = true;
    errorCode.value = '';
    activePageErrorCode.value = '';
    hiddenPageErrorCode.value = '';
    activeHasMore.value = false;
    hiddenHasMore.value = false;
    _activeCursor = null;
    _hiddenCursor = null;
    activeEvents.clear();
    hiddenEvents.clear();
    try {
      final activePage = await service.getEventsPage(active: true);
      final reviewer = canReviewHidden;
      final hiddenPage = reviewer
          ? await service.getEventsPage(active: false)
          : null;
      activeEvents.assignAll(activePage.items);
      _activeCursor = activePage.cursor;
      activeHasMore.value = activePage.hasMore;
      if (hiddenPage != null) {
        hiddenEvents.assignAll(hiddenPage.items);
        _hiddenCursor = hiddenPage.cursor;
        hiddenHasMore.value = hiddenPage.hasMore;
      }
    } on EventDataException {
      errorCode.value = 'malformed_data';
    } on EventServiceException catch (error) {
      errorCode.value = error.code;
    } catch (_) {
      errorCode.value = 'operation_failed';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreActive() async {
    if (isLoading.value || isLoadingMoreActive.value ||
        isLoadingMoreHidden.value || !activeHasMore.value ||
        _activeCursor == null) {
      return;
    }
    isLoadingMoreActive.value = true;
    activePageErrorCode.value = '';
    try {
      final page = await service.getEventsPage(
        active: true, after: _activeCursor,
      );
      final seen = activeEvents.map((event) => event.id).toSet();
      activeEvents.addAll(page.items.where((event) => seen.add(event.id)));
      _activeCursor = page.cursor;
      activeHasMore.value = page.hasMore;
    } on EventDataException {
      activePageErrorCode.value = 'malformed_data';
    } on EventServiceException catch (error) {
      activePageErrorCode.value = error.code;
    } catch (_) {
      activePageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMoreActive.value = false;
    }
  }

  Future<void> loadMoreHidden() async {
    if (isLoading.value || isLoadingMoreActive.value ||
        isLoadingMoreHidden.value || !canReviewHidden ||
        !hiddenHasMore.value || _hiddenCursor == null) {
      return;
    }
    isLoadingMoreHidden.value = true;
    hiddenPageErrorCode.value = '';
    try {
      final page = await service.getEventsPage(
        active: false, after: _hiddenCursor,
      );
      final seen = hiddenEvents.map((event) => event.id).toSet();
      hiddenEvents.addAll(page.items.where((event) => seen.add(event.id)));
      _hiddenCursor = page.cursor;
      hiddenHasMore.value = page.hasMore;
    } on EventDataException {
      hiddenPageErrorCode.value = 'malformed_data';
    } on EventServiceException catch (error) {
      hiddenPageErrorCode.value = error.code;
    } catch (_) {
      hiddenPageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMoreHidden.value = false;
    }
  }
}
