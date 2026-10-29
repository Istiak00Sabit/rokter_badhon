import 'package:get/get.dart';

import '../models/committee_term_model.dart';
import '../services/committee_service.dart';

class CommitteeController extends GetxController {
  final CommitteeService service;

  CommitteeController({CommitteeService? service})
    : service = service ?? CommitteeService();

  final RxBool isLoading = false.obs;
  final Rxn<CommitteeRoster> currentRoster = Rxn<CommitteeRoster>();
  final RxList<CommitteeTermModel> pastTerms = <CommitteeTermModel>[].obs;
  final RxnString errorMessage = RxnString();

  /// Preview is permitted only until Firestore has an active committee term.
  /// An existing term, even with zero members, is authoritative live data.
  static bool needsBundledPreview(CommitteeTermModel? currentTerm) =>
      currentTerm == null;

  Future<void> loadCommittee() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      // The official 2025–2027 roster is always the bundled JSON.
      // Firestore only supplies optional public profile photos, never the
      // committee membership, position or ordering.
      currentRoster.value = await service.getBundledOfficialRoster();
      try {
        pastTerms.assignAll(await service.getPastTerms());
      } catch (_) {
        // Historical Firestore terms are optional and must not hide JSON.
        pastTerms.clear();
      }
    } catch (_) {
      currentRoster.value = null;
      pastTerms.clear();
      errorMessage.value = 'committee_error'.tr;
    } finally {
      isLoading.value = false;
    }
  }
}
