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
    expect(bangla['login'], 'লগইন');
    expect(bangla['register'], 'নিবন্ধন');
    expect(bangla['email'], 'ইমেইল');
    expect(bangla['password'], 'পাসওয়ার্ড');
    expect(bangla['confirm_password'], 'পাসওয়ার্ড নিশ্চিত করুন');
    expect(bangla['forgot_password'], 'পাসওয়ার্ড ভুলে গেছেন?');
    expect(bangla['role.developer_admin'], 'ডেভেলপার অ্যাডমিন');
    expect(english['role.developer_admin'], 'Developer Admin');
  });

  test(
    'auth screens expose the shared visible language switch and common labels',
    () {
      final login = File('lib/views/login_screen.dart').readAsStringSync();
      final registration = File(
        'lib/views/registration_screen.dart',
      ).readAsStringSync();
      expect(login, contains('AuthLanguageSwitch(onPrimary: true)'));
      expect(registration, contains('AuthLanguageSwitch(onPrimary: true)'));
      expect(login, contains("'login'.tr"));
      expect(login, contains("'register'.tr"));
      expect(registration, contains("'register'.tr"));
      final dashboard = File(
        'lib/views/dashboard_screen.dart',
      ).readAsStringSync();
      expect(dashboard, contains('AuthLanguageSwitch(onPrimary: true)'));
      expect(dashboard, contains("'app_name'.tr"));
    },
  );

  test(
    'Firebase emulator mode is explicit and leaves production as the default',
    () {
      final config = File(
        'lib/config/firebase_runtime_config.dart',
      ).readAsStringSync();
      expect(config, contains("'USE_FIREBASE_EMULATOR'"));
      expect(config, contains('defaultValue: false'));
      expect(config, contains('if (!useEmulators) return'));
      expect(config, contains('useAuthEmulator'));
      expect(config, contains('useFirestoreEmulator'));
    },
  );

  test('first launch and invalid preference fall back to Bangla', () {
    final controller = File(
      'lib/controllers/localization_controller.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      controller,
      contains(RegExp(r'const\s+Locale\(\s*AppTranslations\.bangla,\s*\)\.obs')),
    );
    expect(controller, contains("stored == AppTranslations.english"));
    expect(controller, contains("setString(_preferenceKey, normalized)"));
    expect(
      main,
      contains("fallbackLocale: const Locale(AppTranslations.bangla)"),
    );
  });

  test(
    'language-neutral keys and Free V1 dependency boundary remain intact',
    () {
      final donorList = File(
        'lib/views/donor_list_screen.dart',
      ).readAsStringSync();
      final eventModel = File('lib/models/event_model.dart').readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final generatedDesktopSources = [
        'windows/flutter/generated_plugin_registrant.cc',
        'windows/flutter/generated_plugins.cmake',
        'macos/Flutter/GeneratedPluginRegistrant.swift',
        'linux/flutter/generated_plugin_registrant.cc',
        'linux/flutter/generated_plugins.cmake',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(donorList, contains("selectedFilter = 'all'.obs"));
      expect(eventModel, contains("'event_type.\$key'"));
      expect(pubspec, isNot(contains('firebase_storage')));
      expect(pubspec, isNot(contains('image_picker')));
      expect(generatedDesktopSources, isNot(contains('firebase_storage')));
      expect(generatedDesktopSources, isNot(contains('file_selector_')));
    },
  );
}
