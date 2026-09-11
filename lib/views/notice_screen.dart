import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../controllers/notice_controller.dart';
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
      title: const Text('Notices'),
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
          text: _error(controller.errorCode.value),
          retry: controller.load,
        );
      }
      if (controller.published.isEmpty && controller.unpublished.isEmpty) {
        return _Message(
          text: 'No notices are available.',
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
              const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 8),
                child: Text(
                  'Draft and archived review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        '${DateFormat.yMMMd().format(notice.createdAt)}${notice.status == 'published' ? '' : ' • ${notice.status.toUpperCase()}'}',
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
      title: const Text('Notice'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (notice.important)
          const Row(
            children: [
              Icon(Icons.priority_high, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Important',
                style: TextStyle(
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
          DateFormat.yMMMMd().add_jm().format(notice.createdAt),
          style: const TextStyle(color: AppColors.textGrey),
        ),
        if (notice.status != 'published')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              notice.status.toUpperCase(),
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
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'You do not have permission to view these notices.',
  'query_unavailable' => 'The notice query is unavailable.',
  'network_unavailable' => 'Notices are unavailable while offline.',
  'malformed_data' => 'Notice data failed its safety checks.',
  _ => 'Notices could not be loaded.',
};
