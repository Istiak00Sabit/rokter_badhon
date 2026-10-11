import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/notice_model.dart';
import '../services/notice_service.dart';
import 'auth_controller.dart';

class NoticeController extends GetxController {
  final NoticeService service;
  final AuthController auth;
  NoticeController({NoticeService? service, AuthController? auth})
    : service = service ?? NoticeService(),
      auth = auth ?? Get.find<AuthController>();

  final isLoading = false.obs;
  final isLoadingMorePublished = false.obs;
  final isLoadingMoreUnpublished = false.obs;
  final publishedHasMore = false.obs;
  final unpublishedHasMore = false.obs;
  final errorCode = ''.obs;
  final publishedPageErrorCode = ''.obs;
  final unpublishedPageErrorCode = ''.obs;
  final published = <NoticeModel>[].obs;
  final unpublished = <NoticeModel>[].obs;

  final Map<String, DocumentSnapshot<Map<String, dynamic>>?> _cursors = {};
  final Map<String, bool> _more = {};
  static const _reviewStatuses = ['draft', 'archived'];

  bool get canViewUnpublished => {
    'developer_admin',
    'leader',
  }.contains(auth.currentUser.value?.accessRole);

  void _remember(String status, NoticePage page) {
    _cursors[status] = page.cursor;
    _more[status] = page.hasMore;
  }

  void _sortUnpublished() {
    final unique = <String, NoticeModel>{
      for (final item in unpublished) item.id: item,
    };
    unpublished.assignAll(
      unique.values.toList()
        ..sort((left, right) {
          final date = right.createdAt.compareTo(left.createdAt);
          return date != 0 ? date : left.id.compareTo(right.id);
        }),
    );
  }

  Future<void> load() async {
    if (isLoading.value || isLoadingMorePublished.value ||
        isLoadingMoreUnpublished.value) {
      return;
    }
    isLoading.value = true;
    errorCode.value = '';
    publishedPageErrorCode.value = '';
    unpublishedPageErrorCode.value = '';
    publishedHasMore.value = false;
    unpublishedHasMore.value = false;
    _cursors.clear();
    _more.clear();
    published.clear();
    unpublished.clear();
    try {
      final publicPage = await service.getByStatusPage('published');
      final reviewer = canViewUnpublished;
      final reviewPages = reviewer
          ? await Future.wait([
              service.getByStatusPage('draft'),
              service.getByStatusPage('archived'),
            ])
          : <NoticePage>[];
      published.assignAll(publicPage.items);
      _remember('published', publicPage);
      publishedHasMore.value = publicPage.hasMore;
      if (reviewer) {
        for (var i = 0; i < _reviewStatuses.length; i++) {
          final status = _reviewStatuses[i];
          _remember(status, reviewPages[i]);
          unpublished.addAll(reviewPages[i].items);
        }
        _sortUnpublished();
        unpublishedHasMore.value = _reviewStatuses.any(
          (status) => _more[status] == true,
        );
      }
    } on NoticeDataException {
      errorCode.value = 'malformed_data';
    } on NoticeServiceException catch (error) {
      errorCode.value = error.code;
    } catch (_) {
      errorCode.value = 'operation_failed';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMorePublished() async {
    if (isLoading.value || isLoadingMorePublished.value ||
        isLoadingMoreUnpublished.value || !publishedHasMore.value ||
        _cursors['published'] == null) {
      return;
    }
    isLoadingMorePublished.value = true;
    publishedPageErrorCode.value = '';
    try {
      final page = await service.getByStatusPage(
        'published', after: _cursors['published'],
      );
      final seen = published.map((notice) => notice.id).toSet();
      published.addAll(page.items.where((notice) => seen.add(notice.id)));
      _remember('published', page);
      publishedHasMore.value = page.hasMore;
    } on NoticeDataException {
      publishedPageErrorCode.value = 'malformed_data';
    } on NoticeServiceException catch (error) {
      publishedPageErrorCode.value = error.code;
    } catch (_) {
      publishedPageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMorePublished.value = false;
    }
  }

  Future<void> loadMoreUnpublished() async {
    if (isLoading.value || isLoadingMorePublished.value ||
        isLoadingMoreUnpublished.value || !canViewUnpublished ||
        !unpublishedHasMore.value) {
      return;
    }
    isLoadingMoreUnpublished.value = true;
    unpublishedPageErrorCode.value = '';
    try {
      // Commit both review-status pages together. On a partial failure no
      // cursor advances, so Retry cannot permanently miss a document.
      final pages = <String, NoticePage>{};
      for (final status in _reviewStatuses) {
        if (_more[status] != true) continue;
        final cursor = _cursors[status];
        if (cursor == null) {
          throw const NoticeServiceException('operation_failed');
        }
        pages[status] = await service.getByStatusPage(
          status, after: cursor,
        );
      }
      for (final status in _reviewStatuses) {
        final page = pages[status];
        if (page == null) continue;
        unpublished.addAll(page.items);
        _remember(status, page);
      }
      _sortUnpublished();
      unpublishedHasMore.value = _reviewStatuses.any(
        (status) => _more[status] == true,
      );
    } on NoticeDataException {
      unpublishedPageErrorCode.value = 'malformed_data';
    } on NoticeServiceException catch (error) {
      unpublishedPageErrorCode.value = error.code;
    } catch (_) {
      unpublishedPageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMoreUnpublished.value = false;
    }
  }
}
