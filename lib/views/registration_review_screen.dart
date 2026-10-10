import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/administration_controller.dart';
import '../localization/app_date_formatter.dart';

class RegistrationReviewScreen extends StatefulWidget {
  const RegistrationReviewScreen({super.key});

  @override
  State<RegistrationReviewScreen> createState() =>
      _RegistrationReviewScreenState();
}

class _RegistrationReviewScreenState extends State<RegistrationReviewScreen> {
  late final AdministrationController controller;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('pending_registrations'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
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
                Expanded(child: Text('registration_operator_only'.tr)),
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
                child: ListTile(
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
          OutlinedButton(onPressed: retry, child: Text('retry'.tr)),
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
