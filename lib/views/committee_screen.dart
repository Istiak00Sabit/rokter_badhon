import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/committee_controller.dart';
import '../models/committee_member_model.dart';
import '../models/committee_term_model.dart';
import '../services/committee_service.dart';
import 'member_list_screen.dart';

class CommitteeScreen extends StatefulWidget {
  const CommitteeScreen({super.key});

  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  late final CommitteeController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(CommitteeController());
    controller.loadCommittee();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Current Committee'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final error = controller.errorMessage.value;
        if (error != null) {
          return _MessageState(
            icon: Icons.error_outline,
            message: error,
            onRetry: controller.loadCommittee,
          );
        }
        final roster = controller.currentRoster.value;
        return RefreshIndicator(
          onRefresh: controller.loadCommittee,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.to(
                        () => PastCommitteesScreen(controller: controller),
                      ),
                      icon: const Icon(Icons.history),
                      label: Text(
                        'Past Committees (${controller.pastTerms.length})',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.to(() => const MemberListScreen()),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Member Directory'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (roster == null)
                const _EmptyCommittee(
                  message: 'No current committee term is available.',
                )
              else
                CommitteeRosterView(roster: roster),
            ],
          ),
        );
      }),
    );
  }
}

class PastCommitteesScreen extends StatelessWidget {
  final CommitteeController controller;

  const PastCommitteesScreen({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Past Committees'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Obx(() {
        final terms = controller.pastTerms;
        if (terms.isEmpty) {
          return const _EmptyCommittee(
            message: 'No past committee terms are available.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: terms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final term = terms[index];
            return Card(
              color: AppColors.white,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.history, color: AppColors.primary),
                ),
                title: Text(
                  term.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${term.startYear}–${term.endYear}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(
                  () => PastCommitteeDetailScreen(
                    term: term,
                    service: controller.service,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class PastCommitteeDetailScreen extends StatefulWidget {
  final CommitteeTermModel term;
  final CommitteeService service;

  const PastCommitteeDetailScreen({
    required this.term,
    required this.service,
    super.key,
  });

  @override
  State<PastCommitteeDetailScreen> createState() =>
      _PastCommitteeDetailScreenState();
}

class _PastCommitteeDetailScreenState extends State<PastCommitteeDetailScreen> {
  late Future<CommitteeRoster> roster;

  @override
  void initState() {
    super.initState();
    roster = widget.service.getHistoricalRoster(widget.term);
  }

  Future<void> _refresh() async {
    setState(() {
      roster = widget.service.getHistoricalRoster(widget.term);
    });
    await roster;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.term.name),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: FutureBuilder<CommitteeRoster>(
        future: roster,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              message: 'Committee history is unavailable: ${snapshot.error}',
              onRetry: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [CommitteeRosterView(roster: snapshot.requireData)],
            ),
          );
        },
      ),
    );
  }
}

class CommitteeRosterView extends StatelessWidget {
  final CommitteeRoster roster;

  const CommitteeRosterView({required this.roster, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 170,
            child: _CommitteeImage(url: roster.term.groupPhotoUrl, group: true),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          roster.term.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Text(
          '${roster.term.startYear}–${roster.term.endYear}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey),
        ),
        const SizedBox(height: 18),
        if (roster.members.isEmpty)
          const _EmptyCommittee(
            message: 'No committee assignments are available for this term.',
          )
        else
          ...roster.members.map(_CommitteeMemberCard.new),
      ],
    );
  }
}

class _CommitteeMemberCard extends StatelessWidget {
  final CommitteeMemberModel member;

  const _CommitteeMemberCard(this.member);

  @override
  Widget build(BuildContext context) {
    final directory = member.directory;
    return Card(
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 52,
                height: 52,
                child: _CommitteeImage(url: directory?.photoUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.position,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    directory?.name ?? 'Directory entry unavailable',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (directory?.profession?.isNotEmpty == true)
                    Text(
                      directory!.profession!,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  if (directory?.bloodGroup?.isNotEmpty == true)
                    Text(
                      'Blood group: ${directory!.bloodGroup}',
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommitteeImage extends StatelessWidget {
  final String? url;
  final bool group;

  const _CommitteeImage({this.url, this.group = false});

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.primaryLight,
      child: Center(
        child: Icon(
          group ? Icons.groups : Icons.person,
          color: AppColors.primary,
          size: group ? 64 : 30,
        ),
      ),
    );
    if (url == null) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _EmptyCommittee extends StatelessWidget {
  final String message;

  const _EmptyCommittee({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(
            Icons.groups_outlined,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function() onRetry;

  const _MessageState({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textGrey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
