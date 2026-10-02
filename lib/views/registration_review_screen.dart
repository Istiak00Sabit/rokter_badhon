import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/administration_controller.dart';
import '../localization/app_date_formatter.dart';
import '../models/registration_request_model.dart';

class RegistrationReviewScreen extends StatelessWidget {
  const RegistrationReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      AdministrationController(),
      tag: 'registrations',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('pending_registrations'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.pending.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (controller.errorCode.isNotEmpty && controller.pending.isEmpty) {
          return _Message(
            text: _error(controller.errorCode.value).tr,
            retry: controller.loadPending,
          );
        }
        if (controller.pending.isEmpty) {
          return _Message(
            text: 'no_pending_registrations'.tr,
            retry: controller.loadPending,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadPending,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: controller.pending.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final item = controller.pending[index];
              return _RegistrationCard(
                item: item,
                busy: controller.decisionInProgress.value,
                onApprove: () => _approve(context, controller, item),
                onReject: () => _reject(context, controller, item),
              );
            },
          ),
        );
      }),
    );
  }

  Future<void> _approve(
    BuildContext context,
    AdministrationController controller,
    RegistrationRequestModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('approve_registration'.tr),
        content: Text(
          'approve_registration_confirm'.trParams({'name': item.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('approve'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await controller.approveRegistration(item);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('registration_approved'.tr)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error(controller.errorCode.value).tr)),
      );
    }
  }

  Future<void> _reject(
    BuildContext context,
    AdministrationController controller,
    RegistrationRequestModel item,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('reject_registration'.tr),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'rejection_reason'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('reject'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    try {
      await controller.rejectRegistration(
        item,
        reason: reasonController.text,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('registration_rejected'.tr)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error(controller.errorCode.value).tr)),
      );
    } finally {
      reasonController.dispose();
    }
  }
}

class _RegistrationCard extends StatelessWidget {
  final RegistrationRequestModel item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RegistrationCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final location = [
      if (item.village != null && item.village!.isNotEmpty) item.village!,
      if (item.union != null && item.union!.isNotEmpty) item.union!,
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(item.phone),
                      Text(AppDateFormatter.short(item.requestedAt)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.email != null) Text('${'email'.tr}: ${item.email}'),
            if (item.bloodGroup != null)
              Text('${'blood_group'.tr}: ${item.bloodGroup}'),
            if (item.profession != null)
              Text('${'profession'.tr}: ${item.profession}'),
            if (item.address != null)
              Text('${'address'.tr}: ${item.address}'),
            if (location.isNotEmpty) Text('${'location'.tr}: $location'),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: Text('reject'.tr),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check),
                  label: Text('approve'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Future<void> Function() retry;

  const _Message({required this.text, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: retry,
                child: Text('retry'.tr),
              ),
            ],
          ),
        ),
      );
}

String _error(String code) => switch (code) {
      'permission_denied' => 'permission_denied',
      'index_required' => 'query_unavailable',
      'unavailable' => 'network_unavailable',
      'identity_conflict' => 'registration_identity_conflict',
      'already_decided' => 'registration_already_decided',
      'not_found' => 'registration_not_found',
      'session_unavailable' => 'session_unavailable',
      'malformed_data' => 'malformed_data',
      _ => 'registration_review_error',
    };
