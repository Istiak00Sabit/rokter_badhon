import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../data/ghatail_village_data.dart';
import '../services/auth_identity.dart';
import '../models/registration_request_model.dart';
import '../services/auth_services.dart';
import '../widgets/auth_language_switch.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _authService = AuthService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _bloodGroup = TextEditingController();
  final _profession = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  String? _selectedArea;
  int? _selectedWard;
  String? _selectedLocality;
  bool _loading = false;
  bool _locationsReady = false;
  bool _locationLoadFailed = false;
  RegistrationRequestModel? _request;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (_authService.currentUser != null) _refreshStatus();
  }

  Future<void> _loadLocations() async {
    try {
      await GhatailVillageData.load();
      if (!mounted) return;
      setState(() {
        _locationsReady = true;
        _locationLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationLoadFailed = true);
    }
  }

  Future<void> _register() async {
    if (!_validateApplicantFields(includePassword: true)) {
      setState(() => _message = 'registration_invalid');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    final result = await _authService.register(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      password: _password.text,
      bloodGroup: _bloodGroup.text,
      profession: _profession.text,
      address: _address.text,
      union: _selectedArea,
      ward: _selectedWard,
      village: _selectedLocality,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = _registrationMessage(result);
    });
    if (result.requestSubmitted && _authService.currentUser != null) {
      await _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final request = await _authService.getOwnRegistrationRequest();
      if (!mounted) return;
      setState(() {
        _request = request;
        _message ??= request == null ? 'status_unavailable' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'status_unavailable');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitForExistingAccount() async {
    if (!_validateApplicantFields()) {
      setState(() => _message = 'registration_invalid');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _authService.submitOwnRegistrationRequest(
        name: _name.text,
        phone: _phone.text,
        email: _email.text,
        bloodGroup: _bloodGroup.text,
        profession: _profession.text,
        address: _address.text,
        union: _selectedArea,
        ward: _selectedWard,
        village: _selectedLocality,
      );
      _message = _registrationMessage(result);
      if (result.requestSubmitted && _authService.currentUser != null) {
        await _refreshStatus();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = AuthService.mapRegistrationSubmissionError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _bloodGroup.dispose();
    _profession.dispose();
    _address.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _authService.currentUser != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('register'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: AuthLanguageSwitch(onPrimary: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_locationsReady)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: _locationLoadFailed
                      ? Column(
                          children: [
                            Text('location_data_error'.tr),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _loadLocations,
                              child: Text('retry'.tr),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            if (_locationsReady && !signedIn) ...[
              _field(_name, 'name'.tr),
              _field(_phone, 'phone'.tr, type: TextInputType.phone),
              _field(_email, 'email'.tr, type: TextInputType.emailAddress),
              _buildDropdownField(
                label: 'blood_group'.tr,
                value: _bloodGroup.text.isEmpty ? null : _bloodGroup.text,
                items: AppConstants.bloodGroups,
                onChanged: (value) {
                  setState(() => _bloodGroup.text = value ?? '');
                },
              ),
              _field(_profession, 'profession'.tr),
              _buildDropdownField<String>(
                label: 'union_or_municipality'.tr,
                value: _selectedArea,
                items: AppConstants.locationAreas,
                onChanged: (value) {
                  setState(() {
                    _selectedArea = value;
                    _selectedWard = null;
                    _selectedLocality = null;
                  });
                },
              ),
              if (_selectedArea != null && AppConstants.isMunicipality(_selectedArea!))
                _buildDropdownField<int>(
                  label: 'ward'.tr,
                  value: _selectedWard,
                  items: AppConstants.wardsForArea(_selectedArea!),
                  onChanged: (value) {
                    setState(() {
                      _selectedWard = value;
                      _selectedLocality = null;
                    });
                  },
                  itemLabel: (value) => value.toString(),
                ),
              _buildDropdownField<String>(
                label: AppConstants.isMunicipality(_selectedArea ?? '')
                    ? 'mahalla'.tr
                    : 'village'.tr,
                value: _selectedLocality,
                items: _selectedArea == null
                    ? const <String>[]
                    : AppConstants.localitiesForArea(
                        _selectedArea!,
                        ward: _selectedWard,
                      ),
                enabled: _selectedArea != null &&
                    (!AppConstants.isMunicipality(_selectedArea!) ||
                        _selectedWard != null),
                onChanged: (value) {
                  setState(() => _selectedLocality = value);
                },
              ),
              _field(_address, 'address'.tr),
              _field(_password, 'password'.tr, obscure: true),
              _field(
                _passwordConfirmation,
                'confirm_password'.tr,
                obscure: true,
              ),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: Text('register'.tr),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  Text('already_registered'.tr),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('login'.tr),
                  ),
                ],
              ),
            ],
            if (_locationsReady && signedIn) ...[
              Text(
                '${'request_status'.tr}: ${_statusLabel(_request)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_request == null) ...[
                const SizedBox(height: 16),
                _field(_name, 'name'.tr),
                _field(_phone, 'phone'.tr, type: TextInputType.phone),
                _field(_email, 'email'.tr, type: TextInputType.emailAddress),
                _buildDropdownField(
                  label: 'blood_group'.tr,
                  value: _bloodGroup.text.isEmpty ? null : _bloodGroup.text,
                  items: AppConstants.bloodGroups,
                  onChanged: (value) {
                    setState(() => _bloodGroup.text = value ?? '');
                  },
                ),
                _field(_profession, 'profession'.tr),
                _buildDropdownField<String>(
                  label: 'union_or_municipality'.tr,
                  value: _selectedArea,
                  items: AppConstants.locationAreas,
                  onChanged: (value) {
                    setState(() {
                      _selectedArea = value;
                      _selectedWard = null;
                      _selectedLocality = null;
                    });
                  },
                ),
                if (_selectedArea != null && AppConstants.isMunicipality(_selectedArea!))
                  _buildDropdownField<int>(
                    label: 'ward'.tr,
                    value: _selectedWard,
                    items: AppConstants.wardsForArea(_selectedArea!),
                    onChanged: (value) {
                      setState(() {
                        _selectedWard = value;
                        _selectedLocality = null;
                      });
                    },
                    itemLabel: (value) => value.toString(),
                  ),
                _buildDropdownField<String>(
                  label: AppConstants.isMunicipality(_selectedArea ?? '')
                      ? 'mahalla'.tr
                      : 'village'.tr,
                  value: _selectedLocality,
                  items: _selectedArea == null
                      ? const <String>[]
                      : AppConstants.localitiesForArea(
                          _selectedArea!,
                          ward: _selectedWard,
                        ),
                  enabled: _selectedArea != null &&
                      (!AppConstants.isMunicipality(_selectedArea!) ||
                          _selectedWard != null),
                  onChanged: (value) {
                    setState(() => _selectedLocality = value);
                  },
                ),
                _field(_address, 'address'.tr),
                ElevatedButton(
                  onPressed: _loading ? null : _submitForExistingAccount,
                  child: Text('retry_submission'.tr),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loading ? null : _refreshStatus,
                child: Text('refresh_status'.tr),
              ),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!.tr),
              ),
          ],
        ),
      ),
    );
  }

  bool _validateApplicantFields({bool includePassword = false}) {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _selectedArea == null ||
        _selectedLocality == null ||
        (AppConstants.isMunicipality(_selectedArea!) && _selectedWard == null)) {
      return false;
    }
    try {
      AuthIdentity.normalizePhone(_phone.text);
    } on FormatException {
      return false;
    }
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return false;
    }
    if (includePassword &&
        (_password.text.length < 6 ||
            _password.text != _passwordConfirmation.text)) {
      return false;
    }
    return true;
  }

  String _registrationMessage(RegistrationSubmissionResult result) {
    if (result.state == RegistrationSubmissionState.submitted) return 'registration_submitted';
    if (result.state == RegistrationSubmissionState.submittedVerificationEmailFailed) return 'registration_submitted_email_failed';
    if (result.state == RegistrationSubmissionState.submittedSignOutFailed) return 'registration_submitted_signout_failed';
    if (result.state == RegistrationSubmissionState.authCreatedRequestFailed ||
        result.state == RegistrationSubmissionState.failed) {
      return AuthService.mapRegistrationSubmissionError(result.error);
    }
    return 'registration_failed';
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
    String Function(T value)? itemLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel?.call(item) ?? item.toString()),
              ),
            )
            .toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String _statusLabel(RegistrationRequestModel? request) {
    if (request == null) return 'status_unavailable'.tr;
    return switch (request.status) {
      RegistrationRequestStatus.pending => 'status.pending'.tr,
      RegistrationRequestStatus.approved => 'status.approved'.tr,
      RegistrationRequestStatus.rejected => 'status.rejected'.tr,
    };
  }
}
