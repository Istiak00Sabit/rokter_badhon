import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads Ghatail Upazila union/village data from the bundled JSON source.
///
/// Source: ghatail_411_villages_fixed(1).tsv
/// 14 unions / 411 villages.
class GhatailVillageData {
  const GhatailVillageData._();

  static const String assetPath = 'assets/data/ghatail_locations.json';

  static Map<String, List<String>> _villagesByUnion =
      const <String, List<String>>{};

  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static List<String> get unions =>
      List<String>.unmodifiable(_villagesByUnion.keys);

  static Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Ghatail location JSON.');
    }

    final rawUnions = decoded['unions'];
    if (rawUnions is! List) {
      throw const FormatException('Ghatail JSON has no valid unions list.');
    }

    final parsed = <String, List<String>>{};

    for (final item in rawUnions) {
      if (item is! Map) {
        throw const FormatException('Invalid union entry in Ghatail JSON.');
      }

      final name = item['name'];
      final villages = item['villages'];

      if (name is! String || name.trim().isEmpty || villages is! List) {
        throw const FormatException('Invalid union data in Ghatail JSON.');
      }

      parsed[name] = List<String>.unmodifiable(
        villages.whereType<String>().where((v) => v.trim().isNotEmpty),
      );
    }

    if (parsed.length != 14 ||
        parsed.values.fold<int>(0, (sum, list) => sum + list.length) != 411) {
      throw const FormatException(
        'Ghatail JSON must contain exactly 14 unions and 411 villages.',
      );
    }

    _villagesByUnion = Map<String, List<String>>.unmodifiable(parsed);
    _loaded = true;
  }

  static List<String> villagesForUnion(String union) =>
      _villagesByUnion[union] ?? const <String>[];
}
