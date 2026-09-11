import 'package:get/get.dart';

import '../models/blood_request_model.dart';
import '../services/blood_request_service.dart';
import 'auth_controller.dart';

class BloodRequestController extends GetxController {
  final BloodRequestService service;
  final AuthController auth;
  BloodRequestController({BloodRequestService? service, AuthController? auth})
    : service = service ?? BloodRequestService(),
      auth = auth ?? Get.find<AuthController>();

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorCode = ''.obs;
  final active = <BloodRequestModel>[].obs;
  final terminal = <BloodRequestModel>[].obs;
  bool get canViewTerminal => {
    'developer_admin',
    'leader',
    'executive',
  }.contains(auth.currentUser.value?.accessRole);

  Future<void> load() async {
    isLoading.value = true;
    errorCode.value = '';
    try {
      active.assignAll(await service.getByStatus('active'));
      if (canViewTerminal) {
        final values = await Future.wait([
          service.getByStatus('fulfilled'),
          service.getByStatus('cancelled'),
        ]);
        terminal.assignAll(
          [...values[0], ...values[1]]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
      } else {
        terminal.clear();
      }
    } on BloodRequestDataException {
      active.clear();
      terminal.clear();
      errorCode.value = 'malformed_data';
    } on BloodRequestServiceException catch (error) {
      active.clear();
      terminal.clear();
      errorCode.value = error.code;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> create(BloodRequestInput input) async {
    final actor = auth.currentUser.value;
    if (actor == null) {
      errorCode.value = 'session_unavailable';
      return false;
    }
    isSubmitting.value = true;
    errorCode.value = '';
    try {
      await service.create(input, actor.id);
      await load();
      return true;
    } on BloodRequestDataException {
      errorCode.value = 'invalid_input';
      return false;
    } on BloodRequestServiceException catch (error) {
      errorCode.value = error.code;
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
