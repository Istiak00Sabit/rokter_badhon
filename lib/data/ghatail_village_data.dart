import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Complete Ghatail Upazila locality data.
///
/// Source: ghatail_complete_localities_411_villages_plus_municipality.xlsx
/// 14 unions / 411 villages + Ghatail Municipality / 9 wards / 16 mahallas.
class GhatailVillageData {
  const GhatailVillageData._();

  static const String assetPath = 'assets/data/ghatail_locations.json';

  static Map<String, List<String>> _villagesByUnion =
      const <String, List<String>>{};
  static Map<int, List<String>> _municipalityMahallasByWard =
      const <int, List<String>>{};

  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static String get municipalityName => 'ঘাটাইল পৌরসভা';

  static List<String> get unions =>
      List<String>.unmodifiable(_villagesByUnion.keys);

  static List<String> get locationAreas => List<String>.unmodifiable([
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
      parsedUnions[name] = List<String>.unmodifiable(
        villages.whereType<String>().where((v) => v.trim().isNotEmpty),
      );
    }

    final municipalityNameFromJson = rawMunicipality['name'];
    final rawWards = rawMunicipality['wards'];
    if (municipalityNameFromJson != municipalityName || rawWards is! List) {
      throw const FormatException('Invalid municipality data.');
    }

    final parsedWards = <int, List<String>>{};
    for (final item in rawWards) {
      if (item is! Map) {
        throw const FormatException('Invalid municipality ward entry.');
      }
      final ward = item['ward'];
      final mahallas = item['mahallas'];
      if (ward is! int || mahallas is! List) {
        throw const FormatException('Invalid municipality ward data.');
      }
      parsedWards[ward] = List<String>.unmodifiable(
        mahallas.whereType<String>().where((v) => v.trim().isNotEmpty),
      );
    }

    final villageCount =
        parsedUnions.values.fold<int>(0, (sum, list) => sum + list.length);
    final mahallaCount =
        parsedWards.values.fold<int>(0, (sum, list) => sum + list.length);

    if (parsedUnions.length != 14 ||
        villageCount != 411 ||
        parsedWards.length != 9 ||
        mahallaCount != 16) {
      throw const FormatException(
        'Ghatail JSON must contain 14 unions/411 villages and '
        '9 municipality wards/16 mahallas.',
      );
    }

    _villagesByUnion = Map<String, List<String>>.unmodifiable(parsedUnions);
    _municipalityMahallasByWard =
        Map<int, List<String>>.unmodifiable(parsedWards);
    _loaded = true;
  }

  static bool isMunicipality(String area) => area == municipalityName;

  static List<int> wardsForArea(String area) =>
      isMunicipality(area)
          ? List<int>.unmodifiable(
              _municipalityMahallasByWard.keys.toList()..sort(),
            )
          : const <int>[];

  static List<String> localitiesForArea(
    String area, {
    int? ward,
  }) {
    if (isMunicipality(area)) {
      return ward == null
          ? const <String>[]
          : _municipalityMahallasByWard[ward] ?? const <String>[];
    }
    return _villagesByUnion[area] ?? const <String>[];
  }

  static List<String> villagesForUnion(String union) =>
      _villagesByUnion[union] ?? const <String>[];
}
