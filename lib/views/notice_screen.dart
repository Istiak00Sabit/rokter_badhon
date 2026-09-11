import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/notice_controller.dart';
import '../localization/app_date_formatter.dart';
import '../models/notice_model.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});
  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  late final NoticeController controller;
  @override
  void initState() {
    super.initState();
    controller = Get.put(NoticeController());
    controller.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('notices'.tr),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (controller.errorCode.value.isNotEmpty) {
        return _Message(
          text: _error(controller.errorCode.value).tr,
          retry: controller.load,
        );
      }
      if (controller.published.isEmpty && controller.unpublished.isEmpty) {
        return _Message(
          text: 'no_notices_available'.tr,
          retry: controller.load,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ...controller.published.map(
              (notice) => _NoticeCard(notice: notice),
            ),
            if (controller.canViewUnpublished &&
                controller.unpublished.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 8),
                child: Text(
                  'unpublished_review'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...controller.unpublished.map(
                (notice) => _NoticeCard(notice: notice),
              ),
            ],
          ],
        ),
      );
    }),
  );
}

class _NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  const _NoticeCard({required this.notice});
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Icon(
        notice.important ? Icons.priority_high : Icons.campaign_outlined,
        color: notice.important ? AppColors.primary : AppColors.textGrey,
      ),
      title: Text(
        notice.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${AppDateFormatter.short(notice.createdAt)}${notice.status == 'published' ? '' : ' • ${'status.${notice.status}'.tr}'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Get.to(() => NoticeDetailScreen(notice: notice)),
    ),
  );
}

class NoticeDetailScreen extends StatelessWidget {
  final NoticeModel notice;
  const NoticeDetailScreen({required this.notice, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('notice'.tr),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (notice.important)
          Row(
            children: [
              const Icon(Icons.priority_high, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'important'.tr,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          notice.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          AppDateFormatter.dateTime(notice.createdAt),
          style: const TextStyle(color: AppColors.textGrey),
        ),
        if (notice.status != 'published')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'status.${notice.status}'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        const Divider(height: 32),
        Text(notice.body, style: const TextStyle(fontSize: 16, height: 1.5)),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final String text;
  final Future<void> Function() retry;
  const _Message({required this.text, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: Text('retry'.tr)),
      ],
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'permission_denied',
  'query_unavailable' => 'query_unavailable',
  'network_unavailable' => 'network_unavailable',
  'malformed_data' => 'malformed_data',
  _ => 'notices_error',
};
