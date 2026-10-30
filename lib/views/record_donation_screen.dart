import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../localization/app_date_formatter.dart';
import '../models/donor_model.dart';
import '../services/donation_service.dart';

typedef DonationRecorder = Future<String> Function({
  required String donorId,
  required String actorUserId,
  required DateTime donatedAt,
  String? hospital,
  String? location,
});

class RecordDonationScreen extends StatefulWidget {
  final DonorModel donor;
  final DonationRecorder? recorder;

  const RecordDonationScreen({super.key, required this.donor, this.recorder});

  @override
  State<RecordDonationScreen> createState() => _RecordDonationScreenState();
}

class _RecordDonationScreenState extends State<RecordDonationScreen> {
  late DateTime _date = DateTime.now();
  String _hospital = '';
  String _location = '';
  bool _saving = false;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _record() async {
    if (_saving) return;
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null || !{'developer_admin', 'leader', 'executive'}
        .contains(user.accessRole)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('permission_denied'.tr)),
      );
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosen = DateTime(_date.year, _date.month, _date.day);
    // Earlier donations are represented as local midday; for today use the
    // current instant so no future timestamp can enter Firestore.
    final recorded = chosen.isAtSameMomentAs(today)
        ? now.subtract(const Duration(seconds: 30))
        : DateTime(_date.year, _date.month, _date.day, 12);
    if (recorded.isAfter(now) ||
        (widget.donor.lastDonatedAt != null &&
         !recorded.isAfter(widget.donor.lastDonatedAt!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invalid_donation_date'.tr)),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('record_donation_title'.tr),
        content: Text('record_donation_confirm'.trParams({
          'name': widget.donor.name,
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final recorder = widget.recorder ?? DonationService().recordDonation;
      await recorder(
        donorId: widget.donor.id,
        actorUserId: user.id,
        donatedAt: recorded,
        hospital: _hospital.isEmpty ? null : _hospital,
        location: _location.isEmpty ? null : _location,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('donation_recorded'.tr)),
      );
      Navigator.of(context).pop(true);
    } on DonationServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.code.tr)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('operation_failed'.tr)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('record_donation_title'.tr),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textDark,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.donor.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${widget.donor.bloodGroup} · ${widget.donor.phone}',
            style: const TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 12),
          Text('donor_recorded_count'.trParams({
            'count': '${widget.donor.totalDonations}',
          })),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text('donation_date'.tr),
            subtitle: Text(AppDateFormatter.short(_date)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _saving ? null : _selectDate,
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: !_saving,
            onChanged: (value) => _hospital = value.trim(),
            decoration: InputDecoration(labelText: 'hospital'.tr),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: !_saving,
            onChanged: (value) => _location = value.trim(),
            decoration: InputDecoration(labelText: 'location'.tr),
          ),
          const SizedBox(height: 12),
          Text('donation_record_verified_note'.tr,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _record,
              icon: _saving ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ) : const Icon(Icons.check_circle_outline),
              label: Text('record_donation_title'.tr),
            ),
          ),
        ],
      ),
    ),
  );
}
