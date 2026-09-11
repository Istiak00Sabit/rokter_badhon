import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/administration_controller.dart';

class RegistrationReviewScreen extends StatelessWidget {
  const RegistrationReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdministrationController(), tag: 'registrations');
    WidgetsBinding.instance.addPostFrameCallback((_) { if (!controller.isLoading.value && controller.pending.isEmpty) controller.loadPending(); });
    return Scaffold(appBar: AppBar(title: const Text('Pending registrations'), backgroundColor: AppColors.primary, foregroundColor: AppColors.white), body: Obx(() {
      if (controller.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      if (controller.errorCode.isNotEmpty) return _Message(text: _error(controller.errorCode.value), retry: controller.loadPending);
      if (controller.pending.isEmpty) return _Message(text: 'No pending registration requests.', retry: controller.loadPending);
      return RefreshIndicator(onRefresh: controller.loadPending, child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), itemCount: controller.pending.length, itemBuilder: (_, index) {
        final item = controller.pending[index];
        return Card(child: ListTile(leading: const Icon(Icons.person_search, color: AppColors.primary), title: Text(item.name), subtitle: Text('${item.phone}\n${item.email}\nAuth UID: ${item.authUid}'), isThreeLine: true, trailing: Text(_date(item.requestedAt))));
      }));
    }));
  }
}
class _Message extends StatelessWidget { final String text; final Future<void> Function() retry; const _Message({required this.text, required this.retry}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(text, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton(onPressed: retry, child: const Text('Retry'))]))); }
String _error(String code) => switch (code) { 'permission_denied' => 'You do not have permission to review registrations.', 'index_required' => 'The registration review index is not available.', 'unavailable' => 'Registration review is temporarily offline.', 'malformed_data' => 'A registration request has invalid data.', _ => 'Registration requests could not be loaded.' };
String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
