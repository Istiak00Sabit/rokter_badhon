import 'package:get/get.dart';

import '../models/notice_model.dart';
import '../services/notice_service.dart';
import 'auth_controller.dart';

class NoticeController extends GetxController {
  final NoticeService service;
  final AuthController auth;
  NoticeController({NoticeService? service, AuthController? auth})
    : service = service ?? NoticeService(),
      auth = auth ?? Get.find<AuthController>();
  final isLoading = false.obs;
  final errorCode = ''.obs;
  final published = <NoticeModel>[].obs;
  final unpublished = <NoticeModel>[].obs;
  bool get canViewUnpublished => {
    'developer_admin',
    'leader',
  }.contains(auth.currentUser.value?.accessRole);
  Future<void> load() async {
    isLoading.value = true;
    errorCode.value = '';
    try {
      published.assignAll(await service.getByStatus('published'));
      if (canViewUnpublished) {
        final values = await Future.wait([
          service.getByStatus('draft'),
          service.getByStatus('archived'),
        ]);
        unpublished.assignAll(
          [...values[0], ...values[1]]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
      } else {
        unpublished.clear();
      }
    } on NoticeDataException {
      published.clear();
      unpublished.clear();
      errorCode.value = 'malformed_data';
    } on NoticeServiceException catch (error) {
      published.clear();
      unpublished.clear();
      errorCode.value = error.code;
    } finally {
      isLoading.value = false;
    }
  }
}
