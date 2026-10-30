import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../models/donor_model.dart';
import '../services/donor_service.dart';
import '../views/ranklist_screen.dart';

/// A separate live section prevents dashboard stat refreshes from issuing
/// duplicate ranking queries. Firestore updates arrive automatically.
class DashboardTopDonors extends StatefulWidget {
  final Stream<List<DonorModel>>? donorsStream;

  const DashboardTopDonors({super.key, this.donorsStream});

  @override
  State<DashboardTopDonors> createState() => _DashboardTopDonorsState();
}

class _DashboardTopDonorsState extends State<DashboardTopDonors> {
  late Stream<List<DonorModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.donorsStream ?? DonorService().watchTopDonors();
  }

  @override
  void didUpdateWidget(covariant DashboardTopDonors oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.donorsStream != widget.donorsStream) {
      _stream = widget.donorsStream ?? DonorService().watchTopDonors();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'top_donors'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.to(() => const RanklistScreen()),
            child: Text('ranklist'.tr),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'donor_rank_recorded_hint'.tr,
        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<DonorModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Notice(
              icon: Icons.error_outline,
              message: 'ranklist_error'.tr,
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          final donors = snapshot.data!;
          if (donors.isEmpty) {
            return _Notice(
              icon: Icons.hourglass_empty,
              message: 'ranklist_empty'.tr,
            );
          }
          return Column(
            children: [
              for (var index = 0; index < donors.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DonorRow(donor: donors[index], rank: index + 1),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _DonorRow extends StatelessWidget {
  final DonorModel donor;
  final int rank;
  const _DonorRow({required this.donor, required this.rank});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  donor.bloodGroup,
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${donor.totalDonations}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'times'.tr,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Notice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: AppColors.surface,
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.textGrey),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
