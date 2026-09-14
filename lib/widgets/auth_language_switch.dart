import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../controllers/localization_controller.dart';
import '../localization/app_translations.dart';

class AuthLanguageSwitch extends StatelessWidget {
  const AuthLanguageSwitch({super.key, this.onPrimary = false});

  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LocalizationController>();
    final foreground = onPrimary ? AppColors.white : AppColors.primary;
    return Obx(() {
      final current = controller.locale.value.languageCode;
      return Semantics(
        label: 'language'.tr,
        child: Container(
          decoration: BoxDecoration(
            color: onPrimary
                ? AppColors.white.withValues(alpha: 0.16)
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageButton(
                label: 'বাংলা',
                selected: current == AppTranslations.bangla,
                foreground: foreground,
                onPressed: () => controller.setLanguage(AppTranslations.bangla),
              ),
              Text('|', style: TextStyle(color: foreground)),
              _LanguageButton(
                label: 'English',
                selected: current == AppTranslations.english,
                foreground: foreground,
                onPressed: () =>
                    controller.setLanguage(AppTranslations.english),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: selected ? null : onPressed,
    style: TextButton.styleFrom(
      foregroundColor: foreground,
      disabledForegroundColor: foreground,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    ),
    child: Text(
      label,
      style: TextStyle(fontWeight: selected ? FontWeight.bold : null),
    ),
  );
}
