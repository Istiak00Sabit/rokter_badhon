import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rokter_badhon/controllers/localization_controller.dart';
import 'package:rokter_badhon/localization/app_translations.dart';
import 'package:rokter_badhon/widgets/auth_language_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  Future<LocalizationController> pumpSwitch(WidgetTester tester) async {
    final controller = await LocalizationController.create();
    Get.put(controller, permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: controller.locale.value,
        home: const Scaffold(body: AuthLanguageSwitch()),
      ),
    );
    return controller;
  }

  testWidgets('auth language switch starts in Bangla and changes both ways', (
    tester,
  ) async {
    final controller = await pumpSwitch(tester);
    expect(controller.locale.value.languageCode, AppTranslations.bangla);
    expect(find.text('বাংলা'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(controller.locale.value.languageCode, AppTranslations.english);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(controller.locale.value.languageCode, AppTranslations.bangla);
  });

  testWidgets('auth language selection persists through controller restart', (
    tester,
  ) async {
    var controller = await pumpSwitch(tester);
    await controller.setLanguage(AppTranslations.english);

    Get.reset();
    controller = await LocalizationController.create();
    expect(controller.locale.value.languageCode, AppTranslations.english);
  });
}
