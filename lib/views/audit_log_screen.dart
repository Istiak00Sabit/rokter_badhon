import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/administration_controller.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdministrationController(), tag: 'audits');
    WidgetsBinding.instance.addPostFrameCallback((_) { if (!controller.isLoading.value && controller.audits.isEmpty) controller.loadAudits(); });
    return Scaffold(appBar: AppBar(title: const Text('Audit history'), backgroundColor: AppColors.primary, foregroundColor: AppColors.white), body: Obx(() {
      if (controller.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      if (controller.errorCode.isNotEmpty) return _Message(text: _error(controller.errorCode.value), retry: controller.loadAudits);
      if (controller.audits.isEmpty) return _Message(text: 'No audit records are available.', retry: controller.loadAudits);
      return RefreshIndicator(onRefresh: controller.loadAudits, child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), itemCount: controller.audits.length, itemBuilder: (_, index) {
        final item = controller.audits[index];
        return Card(child: ListTile(leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary), title: Text(item.action), subtitle: Text('${item.targetPath}\nActor: ${item.actorUserId}${item.reason == null ? '' : '\nReason: ${item.reason}'}'), isThreeLine: item.reason == null, trailing: Text(_date(item.occurredAt))));
      }));
    }));
  }
}
class _Message extends StatelessWidget { final String text; final Future<void> Function() retry; const _Message({required this.text, required this.retry}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(text, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton(onPressed: retry, child: const Text('Retry'))]))); }
String _error(String code) => switch (code) { 'permission_denied' => 'Only developer_admin may read audit history.', 'unavailable' => 'Audit history is temporarily offline.', 'malformed_data' => 'An audit record has invalid data.', _ => 'Audit history could not be loaded.' };
String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
