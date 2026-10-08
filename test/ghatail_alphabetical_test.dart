import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/data/ghatail_village_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bangla and English values sort alphabetically without changing text', () {
    expect(
      GhatailVillageData.alphabetical(['জামুরিয়া', 'আনেহলা', 'ঘাটাইল']),
      ['আনেহলা', 'ঘাটাইল', 'জামুরিয়া'],
    );
    expect(
      GhatailVillageData.alphabetical(['zeta', 'Alpha', 'beta']),
      ['Alpha', 'beta', 'zeta'],
    );
  });

  test('all 14 unions and municipality have sorted bilingual options', () async {
    await GhatailVillageData.load();
    final bangla = GhatailVillageData.locationAreasForLanguage(english: false);
    final english = GhatailVillageData.locationAreasForLanguage(english: true);
    expect(bangla.length, 15);
    expect(english.length, 15);
    expect(bangla.toSet(), english.toSet());
    expect(bangla, GhatailVillageData.alphabetical(bangla));

    final englishNames = english
        .map((area) => GhatailVillageData.areaLabel(area, english: true))
        .toList();
    expect(englishNames, GhatailVillageData.alphabetical(englishNames));
    expect(
      GhatailVillageData.localitiesForArea('জামুরিয়া'),
      GhatailVillageData.alphabetical(
        GhatailVillageData.localitiesForArea('জামুরিয়া'),
      ),
    );
    expect(
      GhatailVillageData.localitiesForArea(GhatailVillageData.municipalityName),
      GhatailVillageData.alphabetical(
        GhatailVillageData.localitiesForArea(
          GhatailVillageData.municipalityName,
        ),
      ),
    );
  });
}
