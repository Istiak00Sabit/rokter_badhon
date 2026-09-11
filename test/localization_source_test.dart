import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/localization/app_translations.dart';

void main() {
  test('Bangla and English expose the same complete key set', () {
    final keys = AppTranslations().keys;
    final bangla = keys[AppTranslations.bangla]!;
    final english = keys[AppTranslations.english]!;

    expect(bangla.keys.toSet(), english.keys.toSet());
    expect(bangla.length, greaterThan(100));
    expect(bangla['event_type.meeting'], isNot('meeting'));
    expect(english['event_type.meeting'], 'Meeting');
    expect(bangla['position.general_secretary'], isNotNull);
    expect(english['position.general_secretary'], 'General Secretary');
  });

  test('first launch and invalid preference fall back to Bangla', () {
    final controller = File(
      'lib/controllers/localization_controller.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(controller, contains("const Locale(AppTranslations.bangla).obs"));
    expect(controller, contains("stored == AppTranslations.english"));
    expect(controller, contains("setString(_preferenceKey, normalized)"));
    expect(main, contains("fallbackLocale: const Locale(AppTranslations.bangla)"));
  });

  test('language-neutral keys and Free V1 dependency boundary remain intact', () {
    final donorList = File('lib/views/donor_list_screen.dart').readAsStringSync();
    final eventModel = File('lib/models/event_model.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(donorList, contains("selectedFilter = 'all'.obs"));
    expect(eventModel, contains("'event_type.\$key'"));
    expect(pubspec, isNot(contains('firebase_storage')));
    expect(pubspec, isNot(contains('image_picker')));
  });
}
