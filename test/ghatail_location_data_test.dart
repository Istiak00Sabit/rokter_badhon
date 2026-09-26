import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/data/ghatail_village_data.dart';

void main() {
  test('complete Ghatail locality JSON has the exact workbook totals', () async {
    await GhatailVillageData.load();

    expect(GhatailVillageData.unions.length, 14);
    expect(
      GhatailVillageData.unions.fold<int>(
        0,
        (sum, union) => sum + GhatailVillageData.villagesForUnion(union).length,
      ),
      411,
    );
    expect(GhatailVillageData.locationAreas.length, 15);
    expect(
      GhatailVillageData.wardsForArea(GhatailVillageData.municipalityName),
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
    );
    expect(
      GhatailVillageData.localitiesForArea(
        GhatailVillageData.municipalityName,
        ward: 4,
      ).length,
      3,
    );
    expect(
      GhatailVillageData.localitiesForArea(
        GhatailVillageData.municipalityName,
        ward: 9,
      ),
      contains('বানিয়াপাড়া (দক্ষিণ)'),
    );
    expect(
      GhatailVillageData.localitiesForArea(
        GhatailVillageData.municipalityName,
        ward: 8,
      ),
      ['ঘাটাইল'],
    );
  });
}
