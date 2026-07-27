import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/subscriber.dart';
import '../services/subscription_service.dart';

/// Two-step phone + OTP subscription screen.
///
/// Step 1: enter a BD phone number (`01XXXXXXXXX`), request OTP.
/// Step 2: enter the 6-digit OTP, verify, and emit [Subscriber] via
/// [onVerified]. The gate then navigates to the notes app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.subscriptionService,
    required this.onVerified,
    super.key,
  });

  final SubscriptionService subscriptionService;

  /// Invoked with the verified subscriber when OTP verification succeeds.
  /// The gate is responsible for the post-login navigation.
  final ValueChanged<Subscriber> onVerified;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  bool _requesting = false;
  bool _verifying = false;
  String? _referenceNo;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  bool get _isOtpStep => _referenceNo != null;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String _normalisePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '0$digits'; // canonical 01XXXXXXXXX form
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _normalisePhone(_phoneController.text);
    setState(() {
      _requesting = true;
    });

    try {
      final referenceNo = await widget.subscriptionService.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _referenceNo = referenceNo;
        _requesting = false;
      });
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP sent to $phone')),
      );
    } on SubscriptionException catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    await _sendOtp();
  }

  Future<void> _verify() async {
    if (_referenceNo == null) return;
    if (!_otpFormKey.currentState!.validate()) return;

    final phone = _normalisePhone(_phoneController.text);
    setState(() => _verifying = true);

    try {
      final subscriber = await widget.subscriptionService.verifyOtp(
        referenceNo: _referenceNo!,
        otp: _otpController.text.trim(),
        phone: phone,
      );
      if (!mounted) return;
      widget.onVerified(subscriber);
    } on SubscriptionException catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(theme: theme, isOtpStep: _isOtpStep),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isOtpStep
                        ? _OtpForm(
                            key: const ValueKey('otp-form'),
                            formKey: _otpFormKey,
                            controller: _otpController,
                            verifying: _verifying,
                            resendSeconds: _resendSeconds,
                            onSubmit: _verify,
                            onResend: _resend,
                            phone: _normalisePhone(_phoneController.text),
                          )
                        : _PhoneForm(
                            key: const ValueKey('phone-form'),
                            formKey: _phoneFormKey,
                            controller: _phoneController,
                            requesting: _requesting,
                            onSubmit: _sendOtp,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'By continuing you agree to receive a one-time SMS '
                    'verification from BDApps. Standard SMS rates may apply.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme, required this.isOtpStep});

  final ThemeData theme;
  final bool isOtpStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isOtpStep ? Icons.sms_outlined : Icons.lock_outline,
            size: 36,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isOtpStep ? 'Enter verification code' : 'Welcome to Clean Notes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isOtpStep
              ? 'A 6-digit code has been sent to your phone via SMS.'
              : 'Subscribe with your mobile number to access your notes. '
                  'You\'ll receive a one-time SMS to confirm.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PhoneForm extends StatelessWidget {
  const _PhoneForm({
    super.key,
    required this.formKey,
    required this.controller,
    required this.requesting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool requesting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '01XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_iphone),
              prefixText: '+880 ',
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Please enter your phone number';
              final digits = v.replaceAll(RegExp(r'\D'), '');
              final valid = RegExp(r'^(880)?1[3-9]\d{8}$').hasMatch(digits) &&
                  digits.length >= 11;
              if (!valid) return 'Enter a valid BD number, e.g. 01XXXXXXXXX';
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: requesting ? null : onSubmit,
            icon: requesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(requesting ? 'Sending OTP…' : 'Send OTP'),
          ),
        ],
      ),
    );
  }
}

class _OtpForm extends StatelessWidget {
  const _OtpForm({
    super.key,
    required this.formKey,
    required this.controller,
    required this.verifying,
    required this.resendSeconds,
    required this.onSubmit,
    required this.onResend,
    required this.phone,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool verifying;
  final int resendSeconds;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = resendSeconds == 0;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Code sent to $phone',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: '6-digit code',
              counterText: '',
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Please enter the OTP';
              if (v.length != 6) return 'OTP must be 6 digits';
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: verifying ? null : onSubmit,
            icon: verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(verifying ? 'Verifying…' : 'Verify and subscribe'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: canResend ? onResend : null,
            child: Text(
              canResend
                  ? 'Resend code'
                  : 'Resend code in ${resendSeconds}s',
            ),
          ),
        ],
      ),
    );
  }
}