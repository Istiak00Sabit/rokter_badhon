import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_translations.dart';

class LocalizationController extends GetxController {
  static const _preferenceKey = 'app_language';

  final SharedPreferences _preferences;

  final locale = const Locale(
    AppTranslations.bangla,
  ).obs;

  LocalizationController._(
    this._preferences,
  );


  static Future<LocalizationController> create() async {
    final preferences = await SharedPreferences.getInstance();

    final controller = LocalizationController._(
      preferences,
    );


    final stored = preferences.getString(
      _preferenceKey,
    );


    controller.locale.value = Locale(
      stored == AppTranslations.english
          ? AppTranslations.english
          : AppTranslations.bangla,
    );


    return controller;
  }



  Future<void> setLanguage(
    String language,
  ) async {

    final normalized =
        language == AppTranslations.english
            ? AppTranslations.english
            : AppTranslations.bangla;


    final nextLocale = Locale(
      normalized,
    );


    // Update local observable state first
    locale.value = nextLocale;


    // Update the current language even if local preference storage fails.
    try {
      await _preferences.setString(_preferenceKey, normalized);
    } catch (_) {
      // Retry persistence on the next language selection.
    }


    // Get.updateLocale rebuilds the root navigator. Calling it synchronously
    // from a language button may trigger a nested Flutter test frame. Defer
    // the root refresh until the current frame is complete and ignore stale
    // selections if the user switches languages again before the callback.
    if (Get.locale != nextLocale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(Duration.zero, () {
          if (locale.value == nextLocale) {
            Get.updateLocale(nextLocale);
          }
        });
      });
    }
  }
}