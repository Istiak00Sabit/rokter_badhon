import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/blood_request_model.dart';
import '../services/blood_request_service.dart';
import 'auth_controller.dart';

class BloodRequestController extends GetxController {
  final BloodRequestService service;
  final AuthController auth;
  BloodRequestController({BloodRequestService? service, AuthController? auth})
    : service = service ?? BloodRequestService(),
      auth = auth ?? Get.find<AuthController>();

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final isLoadingMoreActive = false.obs;
  final isLoadingMoreTerminal = false.obs;
  final activeHasMore = false.obs;
  final terminalHasMore = false.obs;
  final errorCode = ''.obs;
  final activePageErrorCode = ''.obs;
  final terminalPageErrorCode = ''.obs;
  final active = <BloodRequestModel>[].obs;
  final terminal = <BloodRequestModel>[].obs;

  final Map<String, DocumentSnapshot<Map<String, dynamic>>?> _cursors = {};
  final Map<String, bool> _more = {};
  static const _terminalStatuses = ['fulfilled', 'cancelled'];

  bool get canViewTerminal => {
    'developer_admin',
    'leader',
    'executive',
  }.contains(auth.currentUser.value?.accessRole);

  void _remember(String status, BloodRequestPage page) {
    _cursors[status] = page.cursor;
    _more[status] = page.hasMore;
  }

  void _sortTerminal() {
    final byId = <String, BloodRequestModel>{
      for (final value in terminal) value.id: value,
    };
    terminal.assignAll(
      byId.values.toList()
        ..sort((left, right) {
          final dateOrder = right.createdAt.compareTo(left.createdAt);
          return dateOrder != 0 ? dateOrder : left.id.compareTo(right.id);
        }),
    );
  }

  Future<void> load() async {
    if (isLoading.value || isLoadingMoreActive.value ||
        isLoadingMoreTerminal.value) {
      return;
    }
    isLoading.value = true;
    errorCode.value = '';
    activePageErrorCode.value = '';
    terminalPageErrorCode.value = '';
    activeHasMore.value = false;
    terminalHasMore.value = false;
    _cursors.clear();
    _more.clear();
    active.clear();
    terminal.clear();
    try {
      final activePage = await service.getByStatusPage('active');
      final allowedTerminal = canViewTerminal;
      final terminalPages = allowedTerminal
          ? await Future.wait([
              service.getByStatusPage('fulfilled'),
              service.getByStatusPage('cancelled'),
            ])
          : <BloodRequestPage>[];
      active.assignAll(activePage.items);
      _remember('active', activePage);
      activeHasMore.value = activePage.hasMore;
      if (allowedTerminal) {
        for (var i = 0; i < _terminalStatuses.length; i++) {
          _remember(_terminalStatuses[i], terminalPages[i]);
          terminal.addAll(terminalPages[i].items);
        }
        _sortTerminal();
        terminalHasMore.value = _terminalStatuses.any(
          (status) => _more[status] == true,
        );
      }
    } on BloodRequestDataException {
      errorCode.value = 'malformed_data';
    } on BloodRequestServiceException catch (error) {
      errorCode.value = error.code;
    } catch (_) {
      errorCode.value = 'operation_failed';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreActive() async {
    if (isLoading.value || isLoadingMoreActive.value ||
        isLoadingMoreTerminal.value || !activeHasMore.value ||
        _cursors['active'] == null) {
      return;
    }
    isLoadingMoreActive.value = true;
    activePageErrorCode.value = '';
    try {
      final page = await service.getByStatusPage(
        'active', after: _cursors['active'],
      );
      final seen = active.map((value) => value.id).toSet();
      active.addAll(page.items.where((value) => seen.add(value.id)));
      _remember('active', page);
      activeHasMore.value = page.hasMore;
    } on BloodRequestDataException {
      activePageErrorCode.value = 'malformed_data';
    } on BloodRequestServiceException catch (error) {
      activePageErrorCode.value = error.code;
    } catch (_) {
      activePageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMoreActive.value = false;
    }
  }

  Future<void> loadMoreTerminal() async {
    if (isLoading.value || isLoadingMoreActive.value ||
        isLoadingMoreTerminal.value || !canViewTerminal ||
        !terminalHasMore.value) {
      return;
    }
    isLoadingMoreTerminal.value = true;
    terminalPageErrorCode.value = '';
    try {
      // Read all needed status pages before updating any cursor. A failure in
      // one status never permanently skips records from the other status.
      final fetched = <String, BloodRequestPage>{};
      for (final status in _terminalStatuses) {
        if (_more[status] != true) continue;
        final cursor = _cursors[status];
        if (cursor == null) {
          throw const BloodRequestServiceException('operation_failed');
        }
        fetched[status] = await service.getByStatusPage(
          status, after: cursor,
        );
      }
      for (final status in _terminalStatuses) {
        final page = fetched[status];
        if (page == null) continue;
        terminal.addAll(page.items);
        _remember(status, page);
      }
      _sortTerminal();
      terminalHasMore.value = _terminalStatuses.any(
        (status) => _more[status] == true,
      );
    } on BloodRequestDataException {
      terminalPageErrorCode.value = 'malformed_data';
    } on BloodRequestServiceException catch (error) {
      terminalPageErrorCode.value = error.code;
    } catch (_) {
      terminalPageErrorCode.value = 'operation_failed';
    } finally {
      isLoadingMoreTerminal.value = false;
    }
  }

  Future<bool> create(BloodRequestInput input) async {
    // A second tap/request while the first Firestore write is in flight must
    // never create an additional emergency request.
    if (isSubmitting.value) return false;
    final actor = auth.currentUser.value;
    if (actor == null) {
      errorCode.value = 'session_unavailable';
      return false;
    }
    isSubmitting.value = true;
    errorCode.value = '';
    try {
      await service.create(input, actor.id);
      await load();
      return true;
    } on BloodRequestDataException {
      errorCode.value = 'invalid_input';
      return false;
    } on BloodRequestServiceException catch (error) {
      errorCode.value = error.code;
      return false;
    } catch (_) {
      errorCode.value = 'operation_failed';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
