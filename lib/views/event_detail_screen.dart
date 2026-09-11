import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
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
      title: const Text('Event details'),
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
              label: const Text('Gallery unavailable — retry'),
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
                text: EventModel.typeLabel(value.event.eventType),
              ),
              _Info(
                icon: Icons.schedule,
                text: DateFormat.yMMMMd().add_jm().format(
                  value.event.eventDate,
                ),
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
              const Text(
                'Gallery',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (value.gallery.isEmpty)
                const Text(
                  'No gallery images are available.',
                  style: TextStyle(color: AppColors.textGrey),
                )
              else
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: value.gallery.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) =>
                        _Gallery(media: value.gallery[index]),
                  ),
                ),
            ],
          ),
        );
      },
    ),
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
              '${media.active ? '' : '[HIDDEN] '}${media.caption!}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (media.caption == null && !media.active)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('[HIDDEN]'),
          ),
      ],
    ),
  );
}
