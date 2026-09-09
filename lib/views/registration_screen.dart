import 'package:flutter/material.dart';

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
      setState(
        () => _message =
            'Enter a name, phone, valid email, and matching passwords.',
      );
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
        RegistrationSubmissionState.submitted =>
          'Registration request submitted. Check your email for verification.',
        RegistrationSubmissionState.submittedVerificationEmailFailed =>
          'Request submitted, but the verification email was not sent. Sign in again to resend it.',
        RegistrationSubmissionState.submittedSignOutFailed =>
          'Request submitted, but automatic sign-out failed. Sign out before leaving this screen. Error: ${result.error}',
        RegistrationSubmissionState.authCreatedRequestFailed =>
          'Your sign-in account was created, but the registration request was not saved. Stay signed in and retry later or contact support. Error: ${result.error}',
        RegistrationSubmissionState.failed =>
          'Registration could not start: ${result.error}',
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
        _message ??= request == null
            ? 'Registration status is unavailable.'
            : null;
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Status unavailable: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitForExistingAccount() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _message = 'Enter your name and phone.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _authService.submitOwnRegistrationRequest(
        name: _name.text,
        phone: _phone.text,
      );
      _message = result.state == RegistrationSubmissionState.submitted
          ? 'Registration request submitted.'
          : 'Request submitted, but automatic sign-out failed. Sign out before leaving this screen. Error: ${result.error}';
      if (_authService.currentUser != null) await _refreshStatus();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Request submission failed: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      await _authService.resendEmailVerification();
      if (mounted) setState(() => _message = 'Verification email sent.');
    } catch (error) {
      if (mounted) setState(() => _message = 'Verification email failed: $error');
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
        title: const Text('Registration request'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!signedIn) ...[
              _field(_name, 'Name'),
              _field(_phone, 'Phone', type: TextInputType.phone),
              _field(_email, 'Email', type: TextInputType.emailAddress),
              _field(_password, 'Password', obscure: true),
              _field(
                _passwordConfirmation,
                'Confirm password',
                obscure: true,
              ),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: const Text('Submit registration request'),
              ),
            ],
            if (signedIn) ...[
              Text(
                'Request status: ${_statusLabel(_request)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Email verified: ${_emailVerified ? 'yes' : 'no'}'),
              if (_request == null) ...[
                const SizedBox(height: 16),
                _field(_name, 'Name'),
                _field(_phone, 'Phone', type: TextInputType.phone),
                ElevatedButton(
                  onPressed: _loading ? null : _submitForExistingAccount,
                  child: const Text('Retry request submission'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loading ? null : _refreshStatus,
                child: const Text('Refresh status and verification'),
              ),
              if (!_emailVerified)
                OutlinedButton(
                  onPressed: _loading ? null : _resendVerification,
                  child: const Text('Resend verification email'),
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
                child: Text(_message!),
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
    if (request == null) return 'unavailable';
    return switch (request.status) {
      RegistrationRequestStatus.pending => 'pending',
      RegistrationRequestStatus.approved => 'approved',
      RegistrationRequestStatus.rejected => 'rejected',
    };
  }
}
