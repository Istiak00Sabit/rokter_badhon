import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Complete Ghatail Upazila locality data.
///
/// Source: ghatail_complete_localities_411_villages_plus_municipality.xlsx
/// 14 unions / 411 villages + Ghatail Municipality / 16 mahallas.
class GhatailVillageData {
  const GhatailVillageData._();

  static const String assetPath = 'assets/data/ghatail_locations.json';

  static Map<String, List<String>> _villagesByUnion =
      const <String, List<String>>{};
  static List<String> _municipalityMahallas = const <String>[];

  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static String get municipalityName => 'ঘাটাইল পৌরসভা';

  /// Sorts names alphabetically in their own script. Bangla and English
  /// names remain unchanged, so their saved Firestore values stay stable.
  static List<String> alphabetical(Iterable<String> names) {
    final sorted = names.toList();
    sorted.sort((a, b) {
      final result = a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
      return result != 0 ? result : a.compareTo(b);
    });
    return List<String>.unmodifiable(sorted);
  }

  static List<String> get unions => alphabetical(_villagesByUnion.keys);

  static List<String> get locationAreas => alphabetical([
    ..._villagesByUnion.keys,
    municipalityName,
  ]);

  static Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Ghatail location JSON.');
    }

    final rawUnions = decoded['unions'];
    final rawMunicipality = decoded['municipality'];
    if (rawUnions is! List || rawMunicipality is! Map) {
      throw const FormatException('Incomplete Ghatail location JSON.');
    }

    final parsedUnions = <String, List<String>>{};
    for (final item in rawUnions) {
      if (item is! Map) {
        throw const FormatException('Invalid union entry.');
      }
      final name = item['name'];
      final villages = item['villages'];
      if (name is! String || name.trim().isEmpty || villages is! List) {
        throw const FormatException('Invalid union data.');
      }
      parsedUnions[name] = alphabetical(
        villages.whereType<String>().where((v) => v.trim().isNotEmpty),
      );
    }

    final municipalityNameFromJson = rawMunicipality['name'];
    final rawMahallas = rawMunicipality['mahallas'];
    if (municipalityNameFromJson != municipalityName || rawMahallas is! List) {
      throw const FormatException('Invalid municipality data.');
    }

    final parsedMahallas = alphabetical(
      rawMahallas.whereType<String>().where((v) => v.trim().isNotEmpty),
    );

    final villageCount =
        parsedUnions.values.fold<int>(0, (sum, list) => sum + list.length);

    if (parsedUnions.length != 14 ||
        villageCount != 411 ||
        parsedMahallas.length != 14) {
      throw const FormatException(
        'Ghatail JSON must contain 14 unions/411 villages and '
        '14 unique municipality localities.',
      );
    }

    _villagesByUnion = Map<String, List<String>>.unmodifiable(parsedUnions);
    _municipalityMahallas = parsedMahallas;
    _loaded = true;
  }

  static bool isMunicipality(String area) => area == municipalityName;

  static List<String> localitiesForArea(String area) {
    if (isMunicipality(area)) {
      return _municipalityMahallas;
    }
    return _villagesByUnion[area] ?? const <String>[];
  }

  static List<String> villagesForUnion(String union) =>
      _villagesByUnion[union] ?? const <String>[];
}
