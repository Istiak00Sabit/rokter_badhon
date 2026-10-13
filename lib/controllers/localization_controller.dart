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


    // Save selected language
    await _preferences.setString(
      _preferenceKey,
      normalized,
    );


    // Get.locale only changes the global value. Get.updateLocale also
    // refreshes the GetMaterialApp translation dependents and visible .tr
    // strings. Do not await the framework rebuild from a button callback.
    if (Get.locale != nextLocale) {
      Get.updateLocale(nextLocale);
    }
  }
}