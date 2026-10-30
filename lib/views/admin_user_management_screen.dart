import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../services/admin_functions_service.dart';

/// Only a developer_admin sees this UI. The callable separately verifies the
/// Firebase UID, active AuthLink and User permissions before every mutation.
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  late final AdminFunctionsService backend = AdminFunctionsService();
  late Future<({List<AdminUserSummary> users, bool hasMore})> pending;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      pending = backend.listUsers();
    });
  }

  Future<void> _manage(AdminUserSummary user) async {
    if (busy || user.role == 'developer_admin') return;
    String action = 'role';
    String role = user.role;
    String reasonText = '';
    final result = await showDialog<({String action, String role, String reason})>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(user.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.phone),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: action,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'admin_action'.tr),
                  items: [
                    DropdownMenuItem(value: 'role', child: Text('admin_change_role'.tr)),
                    DropdownMenuItem(value: 'activate', child: Text('admin_activate'.tr)),
                    DropdownMenuItem(value: 'deactivate', child: Text('admin_deactivate'.tr)),
                    DropdownMenuItem(value: 'enable_login', child: Text('admin_enable_login'.tr)),
                    DropdownMenuItem(value: 'disable_login', child: Text('admin_disable_login'.tr)),
                  ],
                  onChanged: (value) => update(() => action = value ?? action),
                ),
                if (action == 'role') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'admin_target_role'.tr),
                    items: ['member', 'committee', 'executive', 'leader'].map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(('role.$value').tr),
                      ),
                    ).toList(),
                    onChanged: (value) => update(() => role = value ?? role),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => reasonText = value,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'admin_reason'.tr),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dialog);
              },
              child: Text('cancel'.tr),
            ),
            FilledButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dialog, (
                  action: action, role: role, reason: reasonText.trim(),
                ));
              },
              child: Text('save'.tr),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin_reason_required'.tr)),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await backend.manageUser(
        userId: user.id,
        action: result.action,
        role: result.action == 'role' ? result.role : null,
        reason: result.reason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('review_saved'.tr)),
      );
    } on AdminCallException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin_action_failed'.trParams({'code': error.code}))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('admin_user_management'.tr),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textDark,
    ),
    body: FutureBuilder<({List<AdminUserSummary> users, bool hasMore})>(
      future: pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('admin_backend_unavailable'.tr),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _refresh, child: Text('retry'.tr)),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
            await pending;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'admin_user_explainer'.tr,
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ),
              if (data.hasMore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('admin_user_list_limit'.tr),
                ),
              for (final user in data.users)
                Card(
                  color: AppColors.surface,
                  child: ListTile(
                    title: Text(user.name),
                    subtitle: Text(
                      '${user.phone} · ${('role.${user.role}').tr}\n'
                      '${user.active ? 'Active' : 'Inactive'} · '
                      '${user.loginEnabled ? 'Login enabled' : 'Login disabled'}',
                    ),
                    trailing: user.role == 'developer_admin'
                        ? const Icon(Icons.lock_outline)
                        : IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: busy ? null : () => _manage(user),
                          ),
                  ),
                ),
              if (data.users.isEmpty)
                Center(child: Text('no_directory_entries'.tr)),
            ],
          ),
        );
      },
    ),
  );
}
