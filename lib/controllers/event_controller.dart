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
  final RxString errorCode = ''.obs;
  final RxList<EventModel> activeEvents = <EventModel>[].obs;
  final RxList<EventModel> hiddenEvents = <EventModel>[].obs;

  bool get canReviewHidden => {
    AppConstants.roleDeveloperAdmin,
    AppConstants.roleLeader,
  }.contains(authController.currentUser.value?.accessRole);

  Future<void> loadEvents() async {
    isLoading.value = true;
    errorCode.value = '';
    try {
      activeEvents.assignAll(await service.getActiveEvents());
      if (canReviewHidden) {
        hiddenEvents.assignAll(await service.getHiddenEvents());
      } else {
        hiddenEvents.clear();
      }
    } on EventDataException {
      activeEvents.clear();
      hiddenEvents.clear();
      errorCode.value = 'malformed_data';
    } on EventServiceException catch (error) {
      activeEvents.clear();
      hiddenEvents.clear();
      errorCode.value = error.code;
    } finally {
      isLoading.value = false;
    }
  }
}
