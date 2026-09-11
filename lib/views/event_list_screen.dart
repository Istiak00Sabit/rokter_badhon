import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../controllers/event_controller.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  late final EventController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(EventController());
    controller.loadEvents();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Events'),
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
          retry: controller.loadEvents,
        );
      }
      if (controller.activeEvents.isEmpty && controller.hiddenEvents.isEmpty) {
        return _Message(
          message: 'No events are available.',
          retry: controller.loadEvents,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.loadEvents,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ...controller.activeEvents.map(
              (event) => _EventCard(
                event: event,
                includeHiddenMedia: controller.canReviewHidden,
              ),
            ),
            if (controller.canReviewHidden &&
                controller.hiddenEvents.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  'Hidden events (review only)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              ...controller.hiddenEvents.map(
                (event) => _EventCard(
                  event: event,
                  hidden: true,
                  includeHiddenMedia: true,
                ),
              ),
            ],
          ],
        ),
      );
    }),
  );
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final bool hidden;
  final bool includeHiddenMedia;
  const _EventCard({
    required this.event,
    this.hidden = false,
    this.includeHiddenMedia = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.white,
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Get.to(
        () => EventDetailScreen(
          event: event,
          includeHiddenMedia: includeHiddenMedia,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: EventNetworkImage(url: event.coverImageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hidden)
                  const Text(
                    'HIDDEN',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${EventModel.typeLabel(event.eventType)}  •  ${DateFormat.yMMMd().add_jm().format(event.eventDate)}',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
                if (event.location != null)
                  Text(
                    event.location!,
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

class EventNetworkImage extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  const EventNetworkImage({
    required this.url,
    this.fallbackIcon = Icons.event,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppColors.primary, size: 52),
    );
    return url == null
        ? fallback
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

class _Message extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _Message({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy, size: 48, color: AppColors.textGrey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'You do not have permission to view these events.',
  'query_unavailable' => 'The event query is not available yet.',
  'network_unavailable' => 'Events are unavailable while offline.',
  'malformed_data' => 'Event data failed its safety checks.',
  _ => 'Events could not be loaded.',
};
