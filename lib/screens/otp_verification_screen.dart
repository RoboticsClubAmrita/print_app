import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/dot_grid.dart';
import '../widgets/fx.dart';
import '../widgets/otp_input.dart';

/// A reusable, premium OTP entry screen: boxed digits, a countdown-gated
/// resend, and a success animation on verification. It is deliberately
/// flow-agnostic — the caller supplies [onVerify] (returns null on success or
/// an error message) and an optional [onResend]. Pops `true` once verified.
class OtpVerificationScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final int length;
  final String verifyLabel;
  final Future<String?> Function(String code) onVerify;
  final Future<String?> Function()? onResend;
  final String successTitle;
  final String? successSubtitle;

  /// Builds the success subtitle after [onVerify] succeeds, for flows whose
  /// message depends on the verification result (e.g. which stack to collect
  /// from). Takes precedence over [successSubtitle].
  final String? Function()? successSubtitleBuilder;
  final IconData successIcon;
  final IconData headerIcon;
  final int resendSeconds;

  const OtpVerificationScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onVerify,
    this.onResend,
    this.length = 4,
    this.verifyLabel = 'Verify',
    this.successTitle = 'Verified',
    this.successSubtitle,
    this.successSubtitleBuilder,
    this.successIcon = Icons.verified_rounded,
    this.headerIcon = Icons.mark_email_read_outlined,
    this.resendSeconds = 30,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _code = '';
  bool _busy = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _countdownLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verify() async {
    if (_busy || _code.length != widget.length) return;
    setState(() => _busy = true);
    final error = await widget.onVerify(_code);
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await showSuccessOverlay(
      context,
      title: widget.successTitle,
      subtitle: widget.successSubtitleBuilder?.call() ?? widget.successSubtitle,
      icon: widget.successIcon,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || widget.onResend == null || _busy) return;
    final error = await widget.onResend!();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'A new code is on its way.')),
    );
    if (error == null) _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _code.length == widget.length && !_busy;
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 28, 28),
                  child: Row(
                    children: [
                      Pressable(
                        pressedScale: 0.9,
                        onTap: () => Navigator.of(context).pop(false),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(color: Colors.white38, width: 1.5),
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
                            'Verification',
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
                      Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            color: AppColors.chip,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.headerIcon,
                              size: 30, color: AppColors.black),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      OtpInput(
                        length: widget.length,
                        enabled: !_busy,
                        onChanged: (code) => setState(() => _code = code),
                        onCompleted: (_) => _verify(),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: canVerify ? _verify : null,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(widget.verifyLabel),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: _secondsLeft > 0
                            ? Text(
                                "Didn't get it? Resend in $_countdownLabel",
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : TextButton(
                                onPressed:
                                    widget.onResend == null ? null : _resend,
                                child: const Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: AppColors.black,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
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
