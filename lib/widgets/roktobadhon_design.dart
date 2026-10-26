import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared responsive visual language inspired by the supplied mobile CSS.
class RBSectionHeader extends StatelessWidget {
  const RBSectionHeader({super.key, required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      ?action,
    ],
  );
}

class RBPageIntro extends StatelessWidget {
  const RBPageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Row(
          children: [
            Icon(icon ?? Icons.location_on_outlined, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                eyebrow!,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
      ],
      Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          height: 1.16,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(
          subtitle!,
          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textGrey),
        ),
      ],
    ],
  );
}

class RBSurface extends StatelessWidget {
  const RBSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = AppColors.surface,
    this.radius = 18,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class RBInfoStrip extends StatelessWidget {
  const RBInfoStrip({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => RBSurface(
    backgroundColor: AppColors.mutedRed,
    padding: const EdgeInsets.all(12),
    radius: 12,
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class RBEmptyPanel extends StatelessWidget {
  const RBEmptyPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => RBSurface(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    child: Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 35),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        ],
      ],
    ),
  );
}

class RBBloodBadge extends StatelessWidget {
  const RBBloodBadge({super.key, required this.group, this.large = false});
  final String group;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    width: large ? 52 : 40,
    height: large ? 52 : 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.mutedRed,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      group,
      style: TextStyle(
        fontSize: large ? 18 : 15,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    ),
  );
}
