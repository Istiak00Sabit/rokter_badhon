import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../controllers/donation_controller.dart';
import '../models/donation_model.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});
  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  late final DonationController controller;
  @override
  void initState() {
    super.initState();
    controller = Get.put(DonationController());
    controller.loadHistory();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Donation history'),
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
          message: _error(controller.errorCode.value),
          retry: controller.loadHistory,
        );
      }
      if (controller.donations.isEmpty) {
        return _Message(
          message: 'No donation history is available.',
          retry: controller.loadHistory,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.loadHistory,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: controller.donations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) =>
              _DonationCard(value: controller.donations[index]),
        ),
      );
    }),
  );
}

class _DonationCard extends StatelessWidget {
  final DonationModel value;
  const _DonationCard({required this.value});
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.white,
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Text(
          value.bloodGroupSnapshot,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        value.donorNameSnapshot,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(DateFormat.yMMMd().format(value.donationDate)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value.hospital != null) Text('Hospital: ${value.hospital}'),
        if (value.location != null) Text('Location: ${value.location}'),
        if (value.recipientName != null)
          Text('Recipient: ${value.recipientName}'),
        if (value.recipientContact != null)
          Text('Contact: ${value.recipientContact}'),
        if (value.updatedAt != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Corrected record',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _Message({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.history, size: 48, color: AppColors.textGrey),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'You do not have permission to view donation history.',
  'network_unavailable' => 'Donation history is unavailable while offline.',
  'malformed_data' => 'Donation data failed its safety checks.',
  _ => 'Donation history could not be loaded.',
};
