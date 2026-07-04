import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address')),
      );
      return;
    }
    setState(() => _sent = true);
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
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: FadeSlideIn(
                          from: Offset(-0.03, 0),
                          child: Text(
                            'Reset Password',
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
                  child: AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _sent
                        ? KeyedSubtree(
                            key: const ValueKey('sent'),
                            child: _sentView(context),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('form'),
                            child: _formView(),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the email linked to your account and we will send you a reset link.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _send(),
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
        const SizedBox(height: 24),
        FilledButton(onPressed: _send, child: const Text('Send Reset Link')),
      ],
    );
  }

  Widget _sentView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.slow,
          curve: AppMotion.spring,
          builder: (context, t, child) =>
              Transform.scale(scale: t, child: child),
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.chip,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 40,
              color: AppColors.black,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'A reset link was sent to ${_email.text.trim()}.\n(Demo app — no email is actually sent.)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }
}
