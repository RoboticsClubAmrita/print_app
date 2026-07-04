import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import 'shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = context
        .read<AppState>()
        .register(_name.text, _email.text, _password.text);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all fields to register')),
      );
      return;
    }
    showSuccessOverlay(
      context,
      title: 'Welcome to PrintEase',
      subtitle: 'Your account is ready.',
      icon: Icons.person_rounded,
    ).then((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
        (route) => false,
      );
    });
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 28, 32),
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
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Full Name',
                          hint: 'Deepa Mohan',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.black,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTheme.fieldTextStyle,
                        decoration: AppTheme.fieldDecoration(
                          label: 'Email',
                          hint: 'you@example.com',
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            color: AppColors.black,
                            size: 20,
                          ),
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
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.black,
                            size: 20,
                          ),
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
                        onPressed: _submit,
                        child: const Text('Create Account'),
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
