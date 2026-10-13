import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rokter_badhon/controllers/localization_controller.dart';
import 'package:rokter_badhon/localization/app_translations.dart';
import 'package:rokter_badhon/widgets/auth_language_switch.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('login headings visibly translate after tapping English then Bangla', (
    tester,
  ) async {
    final controller = await LocalizationController.create();
    Get.put(controller, permanent: true);

    await tester.pumpWidget(
      Obx(
        () => GetMaterialApp(
          translations: AppTranslations(),
          locale: controller.locale.value,
          fallbackLocale: const Locale(AppTranslations.bangla),
          home: const Scaffold(
            body: Column(
              children: [
                AuthLanguageSwitch(),
                _LiveLoginLabels(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('আপনার অ্যাকাউন্টে প্রবেশ করুন'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.locale.value.languageCode, AppTranslations.english);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Access your account'), findsOneWidget);

    await tester.tap(find.text('বাংলা'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('আপনার অ্যাকাউন্টে প্রবেশ করুন'), findsOneWidget);
  });
}

class _LiveLoginLabels extends StatelessWidget {
  const _LiveLoginLabels();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('login_title'.tr),
      Text('login_subtitle'.tr),
    ],
  );
}
