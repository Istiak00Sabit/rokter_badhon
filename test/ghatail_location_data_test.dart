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
    final municipality =
        GhatailVillageData.localitiesForArea(
          GhatailVillageData.municipalityName,
        );
    expect(municipality.length, 14);
    expect(municipality, contains('বানিয়াপাড়া (দক্ষিণ)'));
    expect(municipality, contains('ঘাটাইল'));
  });
}
