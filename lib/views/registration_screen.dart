import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../models/registration_request_model.dart';
import '../services/auth_services.dart';

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
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  bool _loading = false;
  bool _emailVerified = false;
  RegistrationRequestModel? _request;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null) _refreshStatus();
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 6 ||
        _password.text != _passwordConfirmation.text) {
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
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = switch (result.state) {
        RegistrationSubmissionState.submitted => 'registration_submitted',
        RegistrationSubmissionState.submittedVerificationEmailFailed =>
          'registration_submitted_email_failed',
        RegistrationSubmissionState.submittedSignOutFailed =>
          'registration_submitted_signout_failed',
        RegistrationSubmissionState.authCreatedRequestFailed =>
          'registration_request_failed',
        RegistrationSubmissionState.failed => 'registration_failed',
      };
    });
    if (result.requestSubmitted && _authService.currentUser != null) {
      await _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final verified = await _authService.refreshEmailVerification();
      final request = await _authService.getOwnRegistrationRequest();
      if (!mounted) return;
      setState(() {
        _emailVerified = verified;
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
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _message = 'name_phone_required');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _authService.submitOwnRegistrationRequest(
        name: _name.text,
        phone: _phone.text,
      );
      _message = switch (result.state) {
        RegistrationSubmissionState.submitted => 'registration_submitted',
        RegistrationSubmissionState.submittedVerificationEmailFailed =>
          'registration_submitted_email_failed',
        RegistrationSubmissionState.submittedSignOutFailed =>
          'registration_submitted_signout_failed',
        RegistrationSubmissionState.authCreatedRequestFailed =>
          'registration_request_failed',
        RegistrationSubmissionState.failed => 'registration_failed',
      };
      if (result.requestSubmitted && _authService.currentUser != null) {
        await _refreshStatus();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'registration_failed');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      await _authService.resendEmailVerification();
      if (mounted) setState(() => _message = 'verification_sent');
    } catch (_) {
      if (mounted) setState(() => _message = 'verification_failed');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
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
        title: Text('registration_request'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!signedIn) ...[
              _field(_name, 'name'.tr),
              _field(_phone, 'phone'.tr, type: TextInputType.phone),
              _field(_email, 'email'.tr, type: TextInputType.emailAddress),
              _field(_password, 'password'.tr, obscure: true),
              _field(
                _passwordConfirmation,
                'confirm_password'.tr,
                obscure: true,
              ),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: Text('submit_registration'.tr),
              ),
            ],
            if (signedIn) ...[
              Text(
                '${'request_status'.tr}: ${_statusLabel(_request)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${'email_verified'.tr}: ${_emailVerified ? 'yes'.tr : 'no'.tr}',
              ),
              if (_request == null) ...[
                const SizedBox(height: 16),
                _field(_name, 'name'.tr),
                _field(_phone, 'phone'.tr, type: TextInputType.phone),
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
              if (!_emailVerified)
                OutlinedButton(
                  onPressed: _loading ? null : _resendVerification,
                  child: Text('resend_verification'.tr),
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
