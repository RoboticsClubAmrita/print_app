import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import 'otp_verification_screen.dart';

/// Editable profile form: Full Name, Email and Phone, with the same
/// client-side validation as Sign Up. Persisting changes (and the OTP
/// verification required when the email changes) is wired to the backend in
/// Phase B; until then Save validates and explains that saving is coming.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  late final String _originalEmail;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _originalEmail = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter your full name';
    if (!Validators.isAmritaEmail(_email.text)) {
      return 'Use your Amrita email (@amrita.edu)';
    }
    if (!Validators.isValidPhone(_phone.text)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final newEmail = _email.text.trim().toLowerCase();
    final emailChanged = newEmail != _originalEmail.toLowerCase();

    try {
      if (emailChanged) {
        final errorMsg = await state.requestEmailChange(newEmail);
        if (errorMsg != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
          }
          setState(() => _saving = false);
          return;
        }

        if (!mounted) return;
        setState(() => _saving = false);

        final verified = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              title: 'Verify new email',
              subtitle: 'Enter the 4-digit code sent to $newEmail.',
              verifyLabel: 'Verify & Save',
              successTitle: 'Email updated',
              successSubtitle: 'Your profile has been updated.',
              successIcon: Icons.mark_email_read_rounded,
              headerIcon: Icons.mark_email_read_outlined,
              onVerify: (code) => state.verifyEmailChange(code),
              onResend: () => state.requestEmailChange(newEmail),
            ),
          ),
        );

        if (verified != true || !mounted) return;
        setState(() => _saving = true);
      }

      final errorMsg = await state.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (errorMsg != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
        return;
      }

      if (!mounted) return;
      await showSuccessOverlay(
        context,
        title: 'Profile Updated',
        subtitle: 'Changes saved successfully.',
        icon: Icons.person_rounded,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      Pressable(
                        pressedScale: 0.9,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                            border:
                                Border.all(color: Colors.white38, width: 1.5),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: FadeSlideIn(
                          from: Offset(-0.03, 0),
                          child: Text(
                            'Edit Profile',
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
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.black, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Email',
                          prefixIcon: const Icon(Icons.mail_outline_rounded,
                              color: AppColors.black, size: 20),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(6, 6, 6, 0),
                        child: Text(
                          'Changing your email will require OTP verification.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
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
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: AppColors.black, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Save Changes'),
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
