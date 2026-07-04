import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import '../widgets/social_button.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goToApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
      (route) => false,
    );
  }

  void _submit() {
    final ok = context.read<AppState>().login(_email.text, _password.text);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password')),
      );
      return;
    }
    _goToApp();
  }

  void _socialLogin(String provider) {
    // Demo app — social sign-in is mocked and logs you straight in.
    context.read<AppState>().login('$provider.user@print.com', 'demo');
    _goToApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          Expanded(flex: 36, child: _hero()),
          Expanded(
            flex: 64,
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              from: const Offset(0, 0.08),
              child: _sheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Stack(
      children: [
        const Positioned.fill(
          child: DotGrid(color: Colors.white10, spacing: 26, radius: 1.3),
        ),
        Positioned(
          right: -40,
          top: -30,
          child: Icon(
            Icons.print_rounded,
            size: 200,
            color: Colors.white.withValues(alpha: 0.04),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const FadeSlideIn(
                  from: Offset(0, -0.3),
                  child: BrandMark(onDark: true),
                ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  from: const Offset(-0.03, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '👋  Ready to print again?',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Welcome\nBack.',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheet(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Access your orders, billing and prints.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 22),
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
                          hint: '••••••••',
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Sign In'),
                      ),
                      const SizedBox(height: 22),
                      const _OrDivider(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SocialButton(
                              label: 'Google',
                              icon: _googleG(),
                              onTap: () => _socialLogin('google'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SocialButton(
                              label: 'Apple',
                              icon: const Icon(Icons.apple,
                                  size: 22, color: AppColors.black),
                              onTap: () => _socialLogin('apple'),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// A simple monochrome "G" mark for the Google button so the design
  /// stays within the app's black & white palette.
  Widget _googleG() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}
