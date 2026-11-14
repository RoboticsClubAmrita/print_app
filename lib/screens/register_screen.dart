import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import 'otp_verification_screen.dart';
import 'shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _collegeId = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  /// Must match the backend's /auth/register/resend cooldown, or an early
  /// resend is refused.
  static const _resendCooldownSeconds = 60;

  @override
  void dispose() {
    _name.dispose();
    _collegeId.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter your full name';
    if (_collegeId.text.trim().isEmpty) return 'Enter your Roll Number';
    if (!Validators.isValidPhone(_phone.text)) {
      return 'Enter a valid phone number';
    }
    final pwdIssue = Validators.passwordIssue(_password.text);
    if (pwdIssue != null) return pwdIssue;
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _submitting = true);
    final state = context.read<AppState>();
    final collegeId = _collegeId.text.trim().toUpperCase();
    final result = await state.register(
      name: _name.text,
      collegeId: collegeId,
      phone: _phone.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    final sentTo = (result.email?.isNotEmpty ?? false)
        ? result.email!
        : 'your Amrita email';

    // Verify the OTP on the shared premium screen. Verifying creates the
    // account and signs this device in, so no separate login follows.
    // Backing out returns here with the form intact, so the user can fix the
    // roll number and retry.
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          title: 'Verify your email',
          subtitle: 'Enter the 4-digit code sent to $sentTo.\n'
              'Wrong roll number? Go back to change it.',
          verifyLabel: 'Verify email',
          successTitle: 'Email verified',
          successSubtitle: 'Welcome to PrintEase!',
          successIcon: Icons.mark_email_read_rounded,
          headerIcon: Icons.mark_email_read_outlined,
          resendSeconds: _resendCooldownSeconds,
          onVerify: (code) => state.verifyRegistration(collegeId, code),
          onResend: () => state.resendRegistration(collegeId),
        ),
      ),
    );
    if (verified != true || !mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                const Positioned.fill(
                  child:
                      DotGrid(color: Colors.white10, spacing: 26, radius: 1.3),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 28, 24),
                  child: Row(
                    children: [
                      _BackCircle(onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: FadeSlideIn(
                          from: Offset(-0.03, 0),
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              from: const Offset(0, 0.06),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(36)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          'Join with your roll number — your Amrita email is set up automatically.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Full Name',
                          hint: 'Deepa Mohan',
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.black, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _collegeId,
                        textCapitalization: TextCapitalization.characters,
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Roll Number',
                          hint: 'CB.SC.U4XXXXXX',
                          prefixIcon: const Icon(Icons.badge_outlined,
                              color: AppColors.black, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        ],
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Phone Number',
                          hint: '10-digit number',
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: AppColors.black, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Password',
                          hint: 'Minimum 4 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              color: AppColors.black, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.9,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white38, width: 1.5),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.white,
          size: 22,
        ),
      ),
    );
  }
}
