import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../controllers/blood_request_controller.dart';
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
      title: const Text('Blood requests'),
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
      label: const Text('New request'),
    ),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (controller.errorCode.value.isNotEmpty) {
        return _StateMessage(
          message: _error(controller.errorCode.value),
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
              const _Empty(text: 'No active blood requests.')
            else
              ...controller.active.map((value) => _RequestCard(value: value)),
            if (controller.canViewTerminal &&
                controller.terminal.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 8),
                child: Text(
                  'Completed history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        value.patientName ?? 'Patient name unavailable',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${value.hospital}\n${value.location}${value.requiredAt == null ? '' : '\nNeeded: ${DateFormat.yMMMd().add_jm().format(value.requiredAt!)}'}\nContact: ${value.contactName} — ${value.contactPhone}',
      ),
      isThreeLine: true,
      trailing: value.status == 'active'
          ? null
          : Text(
              value.status.toUpperCase(),
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
        SnackBar(content: Text(_error(widget.controller.errorCode.value))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('New blood request'),
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
            decoration: const InputDecoration(labelText: 'Blood group'),
          ),
          _field(patient, 'Patient name (optional)', required: false),
          _field(hospital, 'Hospital'),
          _field(location, 'Location'),
          _field(contact, 'Contact name'),
          _field(phone, 'Contact phone', phone: true),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              requiredAt == null
                  ? 'Required time not specified'
                  : DateFormat.yMMMd().format(requiredAt!),
            ),
            trailing: TextButton(
              onPressed: pickDate,
              child: const Text('Choose date'),
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
                  : const Text('Submit request'),
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
          ? 'Required'
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
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

String _error(String code) => switch (code) {
  'permission_denied' => 'You do not have permission for this request.',
  'query_unavailable' => 'The required request query is unavailable.',
  'network_unavailable' => 'Blood requests are unavailable while offline.',
  'malformed_data' => 'Blood request data failed its safety checks.',
  'invalid_input' => 'Please check the request details.',
  'session_unavailable' => 'Your admitted session is unavailable.',
  _ => 'The request could not be completed.',
};
