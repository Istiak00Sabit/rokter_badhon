import 'package:get/get.dart';

import '../models/audit_log_model.dart';
import '../models/registration_request_model.dart';
import '../services/administration_service.dart';

class AdministrationController extends GetxController {
  final AdministrationService _service;
  AdministrationController({AdministrationService? service}) : _service = service ?? AdministrationService();
  final isLoading = false.obs;
  final errorCode = ''.obs;
  final pending = <RegistrationRequestModel>[].obs;
  final audits = <AuditLogModel>[].obs;

  Future<void> loadPending() async { await _load(() async { pending.assignAll(await _service.pendingRegistrations()); }); }
  Future<void> loadAudits() async { await _load(() async { audits.assignAll(await _service.auditLogs()); }); }
  Future<void> _load(Future<void> Function() action) async {
    isLoading.value = true; errorCode.value = '';
    try { await action(); } on AdministrationServiceException catch (error) { errorCode.value = error.code; } on FormatException { errorCode.value = 'malformed_data'; } catch (_) { errorCode.value = 'unexpected'; } finally { isLoading.value = false; }
  }
}
