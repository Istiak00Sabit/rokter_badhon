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

  Future<void> loadCommittee() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait<dynamic>([
        service.getCurrentTerm(),
        service.getPastTerms(),
      ]);
      final currentTerm = results[0] as CommitteeTermModel?;
      pastTerms.assignAll(results[1] as List<CommitteeTermModel>);
      if (currentTerm == null) {
        currentRoster.value = await service.getBundledOfficialRoster();
      } else {
        final liveRoster = await service.getCurrentRoster(currentTerm);
        // A partially imported official term has no live assignments yet.
        // Show the bundled list until the Firestore import finishes.
        currentRoster.value =
            currentTerm.id == '2025-2027' && liveRoster.members.isEmpty
                ? await service.getBundledOfficialRoster()
                : liveRoster;
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
