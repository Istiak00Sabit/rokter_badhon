import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/event_controller.dart';
import '../localization/app_date_formatter.dart';
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
      title: Text('events'.tr),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textDark,
    ),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (controller.errorCode.value.isNotEmpty) {
        return _Message(
          message: _error(controller.errorCode.value).tr,
          retry: controller.loadEvents,
        );
      }
      if (controller.activeEvents.isEmpty && controller.hiddenEvents.isEmpty) {
        return _Message(
          message: 'events_empty'.tr,
          retry: controller.loadEvents,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.loadEvents,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            ...controller.activeEvents.map(
              (event) => _EventCard(
                event: event,
                includeHiddenMedia: controller.canReviewHidden,
              ),
            ),
            if (controller.activeHasMore.value ||
                controller.activePageErrorCode.value.isNotEmpty)
              _EventPageControl(
                loading: controller.isLoadingMoreActive.value,
                error: controller.activePageErrorCode.value,
                onLoad: controller.loadMoreActive,
              ),
            if (controller.canReviewHidden &&
                controller.hiddenEvents.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  'hidden_events'.tr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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
            if (controller.canReviewHidden &&
                (controller.hiddenHasMore.value ||
                 controller.hiddenPageErrorCode.value.isNotEmpty))
              _EventPageControl(
                loading: controller.isLoadingMoreHidden.value,
                error: controller.hiddenPageErrorCode.value,
                onLoad: controller.loadMoreHidden,
              ),
          ],
        ),
      );
    }),
  );
}

class _EventPageControl extends StatelessWidget {
  final bool loading;
  final String error;
  final Future<void> Function() onLoad;

  const _EventPageControl({
    required this.loading,
    required this.error,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        if (error.isNotEmpty) Text(_error(error).tr),
        if (loading)
          const CircularProgressIndicator()
        else
          OutlinedButton(
            onPressed: onLoad,
            child: Text(error.isNotEmpty ? 'retry'.tr : 'load_more'.tr),
          ),
      ],
    ),
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
                  Text(
                    'hidden'.tr.toUpperCase(),
                    style: const TextStyle(
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
                  '${EventModel.typeTranslationKey(event.eventType).tr}  •  ${AppDateFormatter.dateTime(event.eventDate)}',
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
          OutlinedButton(onPressed: retry, child: Text('retry'.tr)),
        ],
      ),
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'permission_denied',
  'query_unavailable' => 'query_unavailable',
  'network_unavailable' => 'network_unavailable',
  'malformed_data' => 'malformed_data',
  _ => 'events_error',
};
