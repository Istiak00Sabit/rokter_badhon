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


  tearDown(() {
    Get.reset();
  });



  Future<LocalizationController> createController() async {

    final controller =
        await LocalizationController.create();


    Get.put(
      controller,
      permanent: true,
    );


    return controller;
  }



  Widget buildApp(
    LocalizationController controller,
  ) {

    return GetMaterialApp(

      translations: AppTranslations(),

      locale: controller.locale.value,

      fallbackLocale:
          const Locale(
            AppTranslations.bangla,
          ),

      home: const Scaffold(
        body: AuthLanguageSwitch(),
      ),

    );
  }




  testWidgets(
    'auth language switch starts in Bangla and changes both ways',

    (tester) async {

      final controller =
          await createController();


      await tester.pumpWidget(
        buildApp(controller),
      );


      await tester.pump();



      expect(
        controller.locale.value.languageCode,
        AppTranslations.bangla,
      );


      expect(
        find.text('বাংলা'),
        findsOneWidget,
      );


      expect(
        find.text('English'),
        findsOneWidget,
      );



      await tester.tap(
        find.text('English'),
      );


      await tester.pump();


      expect(
        controller.locale.value.languageCode,
        AppTranslations.english,
      );



      await tester.tap(
        find.text('বাংলা'),
      );


      await tester.pump();


      expect(
        controller.locale.value.languageCode,
        AppTranslations.bangla,
      );

    },

  );





  testWidgets(
    'auth language selection persists through controller restart',

    (tester) async {


      final controller =
          await createController();



      await tester.pumpWidget(
        buildApp(controller),
      );



      await controller.setLanguage(
        AppTranslations.english,
      );



      Get.reset();



      final restartedController =
          await LocalizationController.create();



      expect(
        restartedController.locale.value.languageCode,
        AppTranslations.english,
      );

    },

  );

}