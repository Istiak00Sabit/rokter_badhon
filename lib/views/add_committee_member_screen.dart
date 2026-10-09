import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../services/committee_member_admin_service.dart';

class AddCommitteeMemberScreen extends StatefulWidget {
  final String termId;

  const AddCommitteeMemberScreen({super.key, required this.termId});

  @override
  State<AddCommitteeMemberScreen> createState() =>
      _AddCommitteeMemberScreenState();
}

class _AddCommitteeMemberScreenState extends State<AddCommitteeMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _profession = TextEditingController();
  final _position = TextEditingController(text: 'সদস্য');
  String? _bloodGroup;
  bool _saving = false;
  final _service = CommitteeMemberAdminService();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _profession.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final admin = Get.find<AuthController>().currentUser.value;
    if (admin == null || admin.accessRole != AppConstants.roleDeveloperAdmin) {
      Get.snackbar('error'.tr, 'permission_denied'.tr);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.addMember(
        input: CommitteeMemberInput(
          name: _name.text,
          phone: _phone.text,
          profession: _profession.text.trim().isEmpty
              ? null
              : _profession.text,
          bloodGroup: _bloodGroup,
          position: _position.text,
        ),
        termId: widget.termId,
        actorUserId: admin.id,
      );
      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('committee_member_added'.tr, 'committee_no_login'.tr);
    } on CommitteeMemberAdminException catch (error) {
      if (mounted) {
        Get.snackbar('error'.tr, error.message);
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        Get.snackbar(
          'error'.tr,
          error.code == 'permission-denied'
              ? 'permission_denied'.tr
              : 'committee_member_add_error'.tr,
        );
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar('error'.tr, 'committee_member_add_error'.tr);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('add_committee_member'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'committee_no_login'.tr,
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: 'name'.tr),
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : 'committee_required'.tr,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'phone'.tr),
              validator: (value) {
                try {
                  CommitteeMemberInput(
                    name: 'X',
                    phone: value ?? '',
                    position: 'Member',
                    profession: null,
                    bloodGroup: null,
                  ).validateAndNormalizePhone();
                  return null;
                } on CommitteeMemberAdminException {
                  return 'valid_phone_required'.tr;
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _position,
              decoration: InputDecoration(labelText: 'committee_position'.tr),
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : 'committee_required'.tr,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bloodGroup,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'blood_group'.tr),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('unknown'.tr),
                ),
                ...AppConstants.bloodGroups.map(
                  (group) => DropdownMenuItem(
                    value: group,
                    child: Text(group),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _bloodGroup = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _profession,
              decoration: InputDecoration(labelText: 'profession'.tr),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.person_add_alt_1),
              label: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('add_committee_member'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
