import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../localization/app_date_formatter.dart';
import '../services/administration_service.dart';
import '../services/donor_service.dart';

enum ReviewHistoryKind { registration, donor }

class ReviewHistoryEntry {
  final String name;
  final String phone;
  final String status;
  final DateTime decidedAt;
  final String? reason;

  const ReviewHistoryEntry({
    required this.name,
    required this.phone,
    required this.status,
    required this.decidedAt,
    this.reason,
  });
}

/// Read-only decisions. Pending requests are shown in their respective
/// approval screens. Rejection is a recorded decision, never a deletion.
class ReviewHistoryScreen extends StatefulWidget {
  final ReviewHistoryKind kind;
  final Future<List<ReviewHistoryEntry>> Function()? loader;

  const ReviewHistoryScreen({
    super.key,
    required this.kind,
    this.loader,
  });

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  late Future<List<ReviewHistoryEntry>> _history;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _history = widget.loader?.call() ?? _fetch();
  }

  Future<List<ReviewHistoryEntry>> _fetch() async {
    if (widget.kind == ReviewHistoryKind.registration) {
      final requests = await AdministrationService().reviewedRegistrations();
      return requests.map((item) => ReviewHistoryEntry(
        name: item.name,
        phone: item.phone,
        status: item.status.name,
        decidedAt: item.approvedAt ?? item.rejectedAt ?? item.requestedAt,
      )).toList(growable: false);
    }
    final donors = await DonorService().getReviewedSubmissions();
    return donors.map((item) => ReviewHistoryEntry(
      name: item.donor.name,
      phone: item.donor.phone,
      status: item.status,
      decidedAt: item.approvedAt ?? item.rejectedAt ?? item.submittedAt,
      reason: item.rejectionReason,
    )).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('review_history_title'.tr),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textDark,
    ),
    body: FutureBuilder<List<ReviewHistoryEntry>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('review_history_error'.tr),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(_refresh),
                  child: Text('retry'.tr),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const <ReviewHistoryEntry>[];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 46, color: AppColors.textGrey),
                const SizedBox(height: 12),
                Text('review_history_empty'.tr),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(_refresh),
                  child: Text('retry'.tr),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(_refresh);
            await _history;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('review_history_hint'.tr),
              ),
              for (final item in items)
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    leading: Icon(
                      item.status == 'approved'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: item.status == 'approved'
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.phone),
                        Text(AppDateFormatter.short(item.decidedAt)),
                        if (item.reason?.isNotEmpty == true)
                          Text('${'rejection_reason'.tr}: ${item.reason}'),
                      ],
                    ),
                    trailing: Text(
                      ('status.${item.status}').tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: item.status == 'approved'
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
