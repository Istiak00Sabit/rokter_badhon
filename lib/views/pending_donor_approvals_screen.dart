import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<DonorSubmissionModel> _items = const [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _actionInProgress = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = const [];
    _cursor = null;
    _hasMore = false;
    _pageError = null;
    _pending = _firstPage();
  }

  Future<List<DonorSubmissionModel>> _firstPage() async {
    final page = await _service.getPendingSubmissionsPage();
    _items = page.items;
    _cursor = page.cursor;
    _hasMore = page.hasMore;
    return _items;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final page = await _service.getPendingSubmissionsPage(after: _cursor);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } on DonorServiceException catch (error) {
      if (mounted) setState(() => _pageError = error.code);
    } catch (_) {
      if (mounted) setState(() => _pageError = 'operation_failed');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String? get _actorId => Get.find<AuthController>().currentUser.value?.id;

  Future<void> _approve(DonorSubmissionModel submission) async {
    if (_actionInProgress) return;
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
    if (confirmed != true || !mounted) return;
    final actorId = _actorId;
    if (actorId == null) {
      _showError('session_unavailable');
      return;
    }
    await _run(
      () => _service.approveSubmission(
        submission: submission,
        actorUserId: actorId,
      ),
    );
  }

  Future<void> _reject(DonorSubmissionModel submission) async {
    if (_actionInProgress) return;
    String reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reject_donor'.tr),
        content: TextField(
          onChanged: (value) => reasonText = value,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'rejection_reason'.tr),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonText.trim()),
            child: Text('reject'.tr),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    final actorId = _actorId;
    if (actorId == null) {
      _showError('session_unavailable');
      return;
    }
    await _run(
      () => _service.rejectSubmission(
        submission: submission,
        actorUserId: actorId,
        reason: reason,
      ),
    );
  }

  void _showError(String code) {
    if (!mounted) return;
    final label = switch (code) {
      'permission_denied' ||
      'network_unavailable' ||
      'query_unavailable' ||
      'submission_missing' ||
      'already_decided' ||
      'session_unavailable' => code.tr,
      _ => 'operation_failed'.tr,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label)),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('review_saved'.tr)),
      );
    } on DonorServiceException catch (error) {
      _showError(error.code);
    } on DonorDataException {
      _showError('malformed_data');
    } catch (_) {
      _showError('operation_failed');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('donor_approvals_error'.tr),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(_reload),
                  child: Text('retry'.tr),
                ),
              ],
            ),
          );
        }
        final items = _items;
        if (items.isEmpty) return Center(child: Text('no_pending_donors'.tr));
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            try {
              await _pending;
            } catch (_) {
              // FutureBuilder surfaces the failed reload.
            }
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length + (_hasMore || _pageError != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return Center(
                  child: Column(
                    children: [
                      if (_pageError != null)
                        Text(_pageError!.tr),
                      if (_loadingMore)
                        const CircularProgressIndicator()
                      else
                        OutlinedButton(
                          onPressed: _loadMore,
                          child: Text(_pageError == null ? 'load_more'.tr : 'retry'.tr),
                        ),
                    ],
                  ),
                );
              }
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
                            onPressed: _actionInProgress ? null : () => _reject(item),
                            icon: const Icon(Icons.close),
                            label: Text('reject'.tr),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _actionInProgress ? null : () => _approve(item),
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
