import 'package:get/get.dart';

import '../models/audit_log_model.dart';
import '../models/registration_request_model.dart';
import '../services/administration_service.dart';
import 'auth_controller.dart';

class AdministrationController extends GetxController {
  final AdministrationService _service;
  AdministrationController({AdministrationService? service}) : _service = service ?? AdministrationService();
  final isLoading = false.obs;
  final errorCode = ''.obs;
  final pending = <RegistrationRequestModel>[].obs;
  final audits = <AuditLogModel>[].obs;
  final decisionInProgress = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPending();
  }

  Future<void> loadPending() async { await _load(() async { pending.assignAll(await _service.pendingRegistrations()); }); }
  Future<void> approveRegistration(RegistrationRequestModel request) async {
    final actor = Get.find<AuthController>().currentUser.value;
    if (actor == null) {
      throw const AdministrationServiceException('session_unavailable');
    }
    decisionInProgress.value = true;
    errorCode.value = '';
    try {
      await _service.approveRegistration(
        request: request,
        actorUserId: actor.id,
        actorRole: actor.accessRole,
      );
      await loadPending();
    } on AdministrationServiceException catch (error) {
      errorCode.value = error.code;
      rethrow;
    } finally {
      decisionInProgress.value = false;
    }
  }

  Future<void> rejectRegistration(
    RegistrationRequestModel request, {
    String? reason,
  }) async {
    final actor = Get.find<AuthController>().currentUser.value;
    if (actor == null) {
      throw const AdministrationServiceException('session_unavailable');
    }
    decisionInProgress.value = true;
    errorCode.value = '';
    try {
      await _service.rejectRegistration(
        request: request,
        actorUserId: actor.id,
        actorRole: actor.accessRole,
        reason: reason,
      );
      await loadPending();
    } on AdministrationServiceException catch (error) {
      errorCode.value = error.code;
      rethrow;
    } finally {
      decisionInProgress.value = false;
    }
  }

  Future<void> loadAudits() async { await _load(() async { audits.assignAll(await _service.auditLogs()); }); }
  Future<void> _load(Future<void> Function() action) async {
    isLoading.value = true; errorCode.value = '';
    try { await action(); } on AdministrationServiceException catch (error) { errorCode.value = error.code; } on FormatException { errorCode.value = 'malformed_data'; } catch (_) { errorCode.value = 'unexpected'; } finally { isLoading.value = false; }
  }
}
