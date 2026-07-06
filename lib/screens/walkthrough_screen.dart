import 'package:flutter/material.dart';

import '../services/session_store.dart';
import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import 'login_screen.dart';

/// One walkthrough step.
class _Step {
  final IconData icon;
  final String title;
  final String body;
  const _Step(this.icon, this.title, this.body);
}

const _steps = <_Step>[
  _Step(Icons.upload_file_rounded, 'Upload in seconds',
      'Pick any PDF, DOC or image — PrintEase detects the page count for you instantly.'),
  _Step(Icons.tune_rounded, 'Choose your options',
      'Single or double-sided, copies, colour and the exact page range — your call.'),
  _Step(Icons.account_balance_wallet_rounded, 'Pay securely',
      'Checkout with Razorpay. Your total is always clear before you confirm.'),
  _Step(Icons.timeline_rounded, 'Track every step',
      'Watch your job move from queued to printing to ready — live, with notifications.'),
  _Step(Icons.password_rounded, 'Get a pickup OTP',
      "When it's ready, generate a one-time code so only you can collect it."),
  _Step(Icons.inventory_2_rounded, 'Grab & go',
      'Show your OTP at the stack and collect your prints — no queue, no waiting.'),
];

/// The "Explore Printing" onboarding walkthrough. Shown once on first launch
/// (gated by [SessionStore.seenWalkthrough]) and again on demand from
/// Profile → About → View Demo. Pass [replay] = true for the on-demand case so
/// it simply pops instead of advancing to Login and marking the flag.
class WalkthroughScreen extends StatefulWidget {
  final bool replay;
  const WalkthroughScreen({super.key, this.replay = false});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _steps.length - 1;

  Future<void> _finish() async {
    if (widget.replay) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await SessionStore.markWalkthroughSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: AppMotion.normal,
        curve: AppMotion.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DotGrid(color: Colors.white10, spacing: 28, radius: 1.3),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        widget.replay ? 'Close' : 'Skip',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _steps.length,
                    itemBuilder: (_, i) => _StepView(step: _steps[i]),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.ease,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.white
                              : Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.black,
                      ),
                      onPressed: _next,
                      child: Text(_isLast ? 'Get Started' : 'Next'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final _Step step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeSlideIn(
            from: const Offset(0, 0.08),
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppDecor.darkPanelGradient,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Icon(step.icon, size: 56, color: AppColors.white),
            ),
          ),
          const SizedBox(height: 40),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: Text(
              step.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
