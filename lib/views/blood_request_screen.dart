import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/blood_request_controller.dart';
import '../localization/app_date_formatter.dart';
import '../models/blood_request_model.dart';

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({super.key});
  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  late final BloodRequestController controller;
  @override
  void initState() {
    super.initState();
    controller = Get.put(BloodRequestController());
    controller.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text('blood_requests'.tr),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      automaticallyImplyLeading: false,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await Get.to(() => CreateBloodRequestScreen(controller: controller));
        controller.load();
      },
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      icon: const Icon(Icons.add),
      label: Text('new_request'.tr),
    ),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (controller.errorCode.value.isNotEmpty) {
        return _StateMessage(
          message: _error(controller.errorCode.value).tr,
          retry: controller.load,
        );
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            if (controller.active.isEmpty)
              _Empty(text: 'no_active_requests'.tr)
            else
              ...controller.active.map((value) => _RequestCard(value: value)),
            if (controller.canViewTerminal &&
                controller.terminal.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 8),
                child: Text(
                  'completed_history'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...controller.terminal.map((value) => _RequestCard(value: value)),
            ],
          ],
        ),
      );
    }),
  );
}

class _RequestCard extends StatelessWidget {
  final BloodRequestModel value;
  const _RequestCard({required this.value});
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.white,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Text(
          value.bloodGroup,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        value.patientName ?? 'patient_unavailable'.tr,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${value.hospital}\n${value.location}${value.requiredAt == null ? '' : '\n${'needed'.tr}: ${AppDateFormatter.dateTime(value.requiredAt!)}'}\n${'contact'.tr}: ${value.contactName} — ${value.contactPhone}',
      ),
      isThreeLine: true,
      trailing: value.status == 'active'
          ? null
          : Text(
              'status.${value.status}'.tr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
    ),
  );
}

class CreateBloodRequestScreen extends StatefulWidget {
  final BloodRequestController controller;
  const CreateBloodRequestScreen({required this.controller, super.key});
  @override
  State<CreateBloodRequestScreen> createState() =>
      _CreateBloodRequestScreenState();
}

class _CreateBloodRequestScreenState extends State<CreateBloodRequestScreen> {
  final formKey = GlobalKey<FormState>();
  final patient = TextEditingController();
  final hospital = TextEditingController();
  final location = TextEditingController();
  final contact = TextEditingController();
  final phone = TextEditingController();
  String bloodGroup = AppConstants.bloodGroups.first;
  DateTime? requiredAt;
  @override
  void dispose() {
    patient.dispose();
    hospital.dispose();
    location.dispose();
    contact.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: requiredAt ?? DateTime.now(),
    );
    if (date != null) setState(() => requiredAt = date);
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final ok = await widget.controller.create(
      BloodRequestInput(
        bloodGroup: bloodGroup,
        patientName: patient.text.trim().isEmpty ? null : patient.text,
        hospital: hospital.text,
        location: location.text,
        contactName: contact.text,
        contactPhone: phone.text,
        requiredAt: requiredAt,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error(widget.controller.errorCode.value).tr)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('new_blood_request'.tr),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: bloodGroup,
            items: AppConstants.bloodGroups
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => bloodGroup = value!),
            decoration: InputDecoration(labelText: 'blood_group'.tr),
          ),
          _field(patient, 'patient_name_optional'.tr, required: false),
          _field(hospital, 'hospital'.tr),
          _field(location, 'location'.tr),
          _field(contact, 'contact_name'.tr),
          _field(phone, 'contact_phone'.tr, phone: true),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              requiredAt == null
                  ? 'time_not_specified'.tr
                  : AppDateFormatter.short(requiredAt!),
            ),
            trailing: TextButton(
              onPressed: pickDate,
              child: Text('choose_date'.tr),
            ),
          ),
          Obx(
            () => FilledButton(
              onPressed: widget.controller.isSubmitting.value ? null : submit,
              child: widget.controller.isSubmitting.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('submit_request'.tr),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool phone = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: phone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (value) => required && (value == null || value.trim().isEmpty)
          ? 'required'.tr
          : null,
    ),
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(text, style: const TextStyle(color: AppColors.textGrey)),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _StateMessage({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: Text('retry'.tr)),
      ],
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'permission_denied',
  'query_unavailable' => 'query_unavailable',
  'network_unavailable' => 'network_unavailable',
  'malformed_data' => 'malformed_data',
  'invalid_input' => 'invalid_input',
  'session_unavailable' => 'session_unavailable',
  _ => 'request_error',
};
