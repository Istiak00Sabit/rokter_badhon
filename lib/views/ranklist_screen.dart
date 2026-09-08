import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/donor_model.dart';

class RanklistScreen extends StatelessWidget {
  const RanklistScreen({super.key});

  Future<List<DonorModel>> _loadRanklist() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true)
          .orderBy('total_donations', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) =>
              DonorModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('র‍্যাংকলিস্ট'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<DonorModel>>(
        future: _loadRanklist(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final donors = snapshot.data ?? [];

          if (donors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 64, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  const Text('এখনো কোনো রক্তদান রেকর্ড নেই',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textGrey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Force rebuild
              (context as Element).markNeedsBuild();
            },
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top 3 podium
                if (donors.length >= 3) _buildPodium(donors),
                const SizedBox(height: 16),

                // Rest of the list
                ...donors.asMap().entries.skip(donors.length >= 3 ? 3 : 0).map(
                      (entry) => _buildRankCard(entry.key + 1, entry.value),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPodium(List<DonorModel> donors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('শীর্ষ রক্তদাতা',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 2nd place
              _buildPodiumItem(donors[1], 2, 80),
              // 1st place
              _buildPodiumItem(donors[0], 1, 100),
              // 3rd place
              _buildPodiumItem(donors[2], 3, 65),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(DonorModel donor, int rank, double height) {
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(medals[rank]!, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          donor.name.split(' ').first,
          style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          donor.bloodGroup,
          style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.8), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${donor.totalDonations}',
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const Text('বার',
                    style:
                        TextStyle(color: AppColors.white, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(int rank, DonorModel donor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Rank number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textLight),
              ),
              child: Center(
                child: Text('$rank',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey)),
              ),
            ),
            const SizedBox(width: 12),

            // Blood group
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(donor.bloodGroup,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 12),

            // Name & location
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(donor.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  if (donor.union.isNotEmpty)
                    Text(donor.union,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey)),
                ],
              ),
            ),

            // Donation count
            Column(
              children: [
                Text('${donor.totalDonations}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const Text('বার',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}