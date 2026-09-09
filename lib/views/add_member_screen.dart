import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AddMemberScreen extends StatelessWidget {
  const AddMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add member'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Direct member creation is unavailable. Membership admission must be completed through reviewed trusted operator tooling.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textGrey),
          ),
        ),
      ),
    );
  }
}
