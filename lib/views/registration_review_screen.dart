import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/administration_controller.dart';
import '../localization/app_date_formatter.dart';
import '../services/admin_functions_service.dart';
import 'review_history_screen.dart';

class RegistrationReviewScreen extends StatefulWidget {
  const RegistrationReviewScreen({super.key});

  @override
  State<RegistrationReviewScreen> createState() =>
      _RegistrationReviewScreenState();
}

class _RegistrationReviewScreenState extends State<RegistrationReviewScreen> {
  late final AdministrationController controller;
  late final AdminFunctionsService backend = AdminFunctionsService();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    // Loading in build() caused repeated reads whenever the list was empty
    // or a query had failed. Fetch once per screen opening; Retry is explicit.
    controller = Get.isRegistered<AdministrationController>(
      tag: 'registrations',
    )
        ? Get.find<AdministrationController>(tag: 'registrations')
        : Get.put(AdministrationController(), tag: 'registrations');
    controller.loadPending();
  }

  Future<void> _review(String uid, bool approve) async {
    if (saving) return;
    String reasonText = '';
    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(approve ? 'approve'.tr : 'reject'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('registration_review_reason_hint'.tr),
            TextField(
              onChanged: (value) => reasonText = value,
              maxLength: 500,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'rejection_reason'.tr),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialog);
            },
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialog, reasonText.trim());
            },
            child: Text(approve ? 'approve'.tr : 'reject'.tr),
          ),
        ],
      ),
    );
    if (confirmedReason == null || !mounted) return;
    if (confirmedReason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin_reason_required'.tr)),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await backend.decideRegistration(
        applicantUid: uid,
        approve: approve,
        reason: confirmedReason,
      );
      await controller.loadPending();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'review_approved'.tr : 'review_rejected'.tr)),
      );
    } on AdminCallException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin_action_failed'.trParams({'code': error.code}))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('pending_registrations'.tr),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'review_history_title'.tr,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReviewHistoryScreen(
                  kind: ReviewHistoryKind.registration,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('registration_admin_actions_note'.tr)),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (controller.errorCode.isNotEmpty) {
          return _Message(
            text: _error(controller.errorCode.value).tr,
            retry: controller.loadPending,
          );
        }
        if (controller.pending.isEmpty) {
          return _Message(
            text: 'no_pending_registrations'.tr,
            retry: controller.loadPending,
            showHistory: true,
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadPending,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: controller.pending.length,
            itemBuilder: (_, index) {
              final item = controller.pending[index];
              return Card(
                child: Column(
                  children: [
                    ListTile(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: item.authUid));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('registration_uid_copied'.tr)),
                    );
                  },
                  leading: const Icon(
                    Icons.person_search,
                    color: AppColors.primary,
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.phone}\n${item.email ?? ''}\n${item.union ?? ''}${item.village == null ? '' : ', ${item.village}'}\n${'auth_uid'.tr}: ${item.authUid}',
                  ),
                  isThreeLine: true,
                  trailing: Text(AppDateFormatter.short(item.requestedAt)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        children: [
                          Expanded(child: OutlinedButton(
                            onPressed: saving ? null : () => _review(item.authUid, false),
                            child: Text('reject'.tr),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: FilledButton(
                            onPressed: saving ? null : () => _review(item.authUid, true),
                            child: Text('approve'.tr),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
            }),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Future<void> Function() retry;
  final bool showHistory;
  const _Message({required this.text, required this.retry, this.showHistory = false});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHistory) const Icon(Icons.task_alt, size: 48, color: AppColors.success),
          if (showHistory) const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: Text('retry'.tr)),
          if (showHistory) ...[
            const SizedBox(height: 8),
            Text('review_history_hint'.tr, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.history),
              label: Text('review_history_title'.tr),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ReviewHistoryScreen(kind: ReviewHistoryKind.registration),
              )),
            ),
          ],
        ],
      ),
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'permission_denied',
  'index_required' => 'query_unavailable',
  'unavailable' => 'network_unavailable',
  'malformed_data' => 'malformed_data',
  _ => 'registration_review_error',
};
