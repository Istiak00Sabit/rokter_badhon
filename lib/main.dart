import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'constants/app_themes.dart';
import 'views/splash_screen.dart';
import 'controllers/localization_controller.dart';
import 'localization/app_translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('bn');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Get.put(await LocalizationController.create(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = Get.find<LocalizationController>();
    return Obx(
      () => GetMaterialApp(
        title: 'app_name'.tr,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        translations: AppTranslations(),
        locale: localization.locale.value,
        fallbackLocale: const Locale(AppTranslations.bangla),
        home: const SplashScreen(),
      ),
    );
  }
}
