import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../localization/app_date_formatter.dart';
import '../models/event_media_model.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'event_list_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;
  final EventService? service;
  final bool includeHiddenMedia;
  const EventDetailScreen({
    required this.event,
    this.service,
    this.includeHiddenMedia = false,
    super.key,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventService service;
  late Future<EventDetail> detail;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? EventService();
    detail = service.getDetail(
      widget.event,
      includeHiddenMedia: widget.includeHiddenMedia,
    );
  }

  Future<void> _reload() async {
    setState(
      () => detail = service.getDetail(
        widget.event,
        includeHiddenMedia: widget.includeHiddenMedia,
      ),
    );
    await detail;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('event_details'.tr),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    body: FutureBuilder<EventDetail>(
      future: detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: Text('gallery_retry'.tr),
            ),
          );
        }
        final value = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 210,
                  child: EventNetworkImage(url: value.event.coverImageUrl),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value.event.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _Info(
                icon: Icons.category_outlined,
                text: EventModel.typeTranslationKey(value.event.eventType).tr,
              ),
              _Info(
                icon: Icons.schedule,
                text: AppDateFormatter.dateTime(value.event.eventDate),
              ),
              if (value.event.location != null)
                _Info(
                  icon: Icons.location_on_outlined,
                  text: value.event.location!,
                ),
              if (value.event.description != null) ...[
                const SizedBox(height: 14),
                Text(value.event.description!),
              ],
              const SizedBox(height: 22),
              Text(
                'gallery'.tr,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _EventGalleryPager(
                detail: value,
                service: service,
                includeHiddenMedia: widget.includeHiddenMedia,
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _EventGalleryPager extends StatefulWidget {
  final EventDetail detail;
  final EventService service;
  final bool includeHiddenMedia;

  const _EventGalleryPager({
    required this.detail,
    required this.service,
    required this.includeHiddenMedia,
  });

  @override
  State<_EventGalleryPager> createState() => _EventGalleryPagerState();
}

class _EventGalleryPagerState extends State<_EventGalleryPager> {
  late List<EventMediaModel> media;
  DocumentSnapshot<Map<String, dynamic>>? activeCursor;
  DocumentSnapshot<Map<String, dynamic>>? hiddenCursor;
  bool hasMoreActive = false;
  bool hasMoreHidden = false;
  bool loading = false;
  bool failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant _EventGalleryPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.detail, widget.detail)) _reset();
  }

  void _reset() {
    _generation++;
    media = List<EventMediaModel>.of(widget.detail.gallery);
    activeCursor = widget.detail.activeCursor;
    hiddenCursor = widget.detail.hiddenCursor;
    hasMoreActive = widget.detail.hasMoreActive;
    hasMoreHidden =
        widget.includeHiddenMedia && widget.detail.hasMoreHidden;
    loading = false;
    failed = false;
  }

  bool get hasMore => hasMoreActive || hasMoreHidden;

  Future<void> _loadMore() async {
    if (loading || !hasMore) return;
    final requestGeneration = _generation;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      // Keep both cursors unchanged until both reads succeed.
      final activePage = hasMoreActive && activeCursor != null
          ? await widget.service.getMediaPage(
              widget.detail.event.id,
              active: true,
              after: activeCursor,
            )
          : null;
      final hiddenPage = hasMoreHidden && hiddenCursor != null
          ? await widget.service.getMediaPage(
              widget.detail.event.id,
              active: false,
              after: hiddenCursor,
            )
          : null;
      if ((hasMoreActive && activePage == null) ||
          (hasMoreHidden && hiddenPage == null)) {
        throw StateError('Missing gallery cursor');
      }
      if (!mounted || requestGeneration != _generation) return;
      setState(() {
        final byId = <String, EventMediaModel>{
          for (final item in media) item.id: item,
          for (final item in activePage?.items ?? <EventMediaModel>[]) item.id: item,
          for (final item in hiddenPage?.items ?? <EventMediaModel>[]) item.id: item,
        };
        media = byId.values.toList()
          ..sort((left, right) {
            final sort = left.sortOrder.compareTo(right.sortOrder);
            return sort != 0 ? sort : left.id.compareTo(right.id);
          });
        if (activePage != null) {
          activeCursor = activePage.cursor;
          hasMoreActive = activePage.hasMore;
        }
        if (hiddenPage != null) {
          hiddenCursor = hiddenPage.cursor;
          hasMoreHidden = hiddenPage.hasMore;
        }
      });
    } catch (_) {
      if (mounted && requestGeneration == _generation) {
        setState(() => failed = true);
      }
    } finally {
      if (mounted && requestGeneration == _generation) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (media.isEmpty)
        Text(
          'no_gallery_images'.tr,
          style: const TextStyle(color: AppColors.textGrey),
        )
      else
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => _Gallery(media: media[index]),
          ),
        ),
      if (failed)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('gallery_retry'.tr),
        ),
      if (hasMore || failed)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: loading
              ? const CircularProgressIndicator()
              : OutlinedButton(
                  onPressed: _loadMore,
                  child: Text(failed ? 'retry'.tr : 'load_more'.tr),
                ),
        ),
    ],
  );
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Gallery extends StatelessWidget {
  final EventMediaModel media;
  const _Gallery({required this.media});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            width: 250,
            child: EventNetworkImage(
              url: media.imageUrl,
              fallbackIcon: Icons.broken_image_outlined,
            ),
          ),
        ),
        if (media.caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${media.active ? '' : '${'hidden'.tr.toUpperCase()} '}${media.caption!}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (media.caption == null && !media.active)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('hidden'.tr.toUpperCase()),
          ),
      ],
    ),
  );
}
