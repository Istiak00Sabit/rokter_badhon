import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../localization/app_date_formatter.dart';
import '../models/donor_submission_model.dart';
import '../services/donor_service.dart';

class PendingDonorApprovalsScreen extends StatefulWidget {
  const PendingDonorApprovalsScreen({super.key});

  @override
  State<PendingDonorApprovalsScreen> createState() =>
      _PendingDonorApprovalsScreenState();
}

class _PendingDonorApprovalsScreenState
    extends State<PendingDonorApprovalsScreen> {
  final DonorService _service = DonorService();
  late Future<List<DonorSubmissionModel>> _pending;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _pending = _service.getPendingSubmissions();

  String get _actorId => Get.find<AuthController>().currentUser.value!.id;

  Future<void> _approve(DonorSubmissionModel submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('approve_donor'.tr),
        content: Text(
          'approve_donor_confirm'.trParams({'name': submission.donor.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('approve'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _service.approveSubmission(
        submission: submission,
        actorUserId: _actorId,
      ),
    );
  }

  Future<void> _reject(DonorSubmissionModel submission) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reject_donor'.tr),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'rejection_reason'.tr),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('reject'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || reason.text.trim().isEmpty) return;
    await _run(
      () => _service.rejectSubmission(
        submission: submission,
        actorUserId: _actorId,
        reason: reason.text,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('review_saved'.tr)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('operation_failed'.tr)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('pending_donor_approvals'.tr)),
    body: FutureBuilder<List<DonorSubmissionModel>>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('donor_approvals_error'.tr));
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return Center(child: Text('no_pending_donors'.tr));
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final donor = item.donor;
              final location =
                  [donor.village, donor.union, donor.upazila, donor.district]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(', ');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            child: Text(
                              donor.bloodGroup,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  donor.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${donor.phone} • ${AppDateFormatter.short(item.submittedAt)}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (donor.gender != null)
                        Text('${'gender'.tr}: ${donor.gender}'),
                      if (donor.profession != null)
                        Text('${'profession'.tr}: ${donor.profession}'),
                      Text('${'location'.tr}: $location'),
                      Text('${'submitted_by'.tr}: ${item.submittedBy}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _reject(item),
                            icon: const Icon(Icons.close),
                            label: Text('reject'.tr),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _approve(item),
                            icon: const Icon(Icons.check),
                            label: Text('approve'.tr),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
