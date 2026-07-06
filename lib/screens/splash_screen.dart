import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_store.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import 'login_screen.dart';
import 'shell_screen.dart';
import 'walkthrough_screen.dart';

/// Dark hero landing screen — branded entry point with the same
/// dot-grid texture and watermark used across the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checking = false;

  Future<void> _explore() async {
    setState(() => _checking = true);

    // First-run gate: show the onboarding walkthrough once.
    final seenWalkthrough = await SessionStore.seenWalkthrough;
    if (!mounted) return;
    if (!seenWalkthrough) {
      setState(() => _checking = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WalkthroughScreen()),
      );
      if (!mounted) return;
      // After finishing the walkthrough, proceed to session restore.
      setState(() => _checking = true);
    }

    final restored = await context.read<AppState>().restoreSession();
    if (!mounted) return;
    setState(() => _checking = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => restored ? const ShellScreen() : const LoginScreen(),
      ),
    );
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
          Positioned(
            right: -50,
            top: 90,
            child: Icon(
              Icons.print_rounded,
              size: 240,
              color: Colors.white.withValues(alpha: 0.035),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const FadeSlideIn(
                    from: Offset(0, -0.3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandMark(onDark: true),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Center(
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const _PulseRings(),
                          const FadeSlideIn(
                            delay: Duration(milliseconds: 120),
                            from: Offset.zero,
                            child: AppIconTile(size: 104),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 220),
                    child: Text(
                      'Own Your\nPrints.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 42,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: const Text(
                          'Upload documents, customize print settings and '
                          'collect your prints — without the queue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 420),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.black,
                      ),
                      onPressed: _checking ? null : _explore,
                      child: _checking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Explore Printing'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two rings that slowly expand and fade behind the brand badge,
/// giving the landing screen a calm heartbeat.
class _PulseRings extends StatefulWidget {
  const _PulseRings();

  @override
  State<_PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<_PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _ring(double phase) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = (_controller.value + phase) % 1.0;
        final scale = 0.55 + t * 0.45;
        final opacity = (1 - t) * 0.30;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [_ring(0), _ring(0.5)],
    );
  }
}
