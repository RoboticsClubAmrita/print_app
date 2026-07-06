import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A row of individual OTP digit boxes with auto-advance and
/// backspace-to-previous focus handling. Reports the assembled code via
/// [onChanged] and fires [onCompleted] once every box is filled.
class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autofocus;

  const OtpInput({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) {
      final node = FocusNode();
      // Repaint the box so its border reflects the focused state.
      node.addListener(() {
        if (mounted) setState(() {});
      });
      return node;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _emit() {
    final code = _code;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty) {
      _focusNodes[index].unfocus();
    }
    _emit();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    // Backspace on an already-empty box steps back and clears the previous
    // digit, matching the behaviour users expect from OTP fields.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _emit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          _box(i),
          if (i < widget.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _box(int i) {
    final focused = _focusNodes[i].hasFocus;
    final filled = _controllers[i].text.isNotEmpty;
    return SizedBox(
      width: 58,
      height: 64,
      child: Focus(
        onKeyEvent: (_, event) => _onKey(i, event),
        child: TextField(
          controller: _controllers[i],
          focusNode: _focusNodes[i],
          enabled: widget.enabled,
          autofocus: widget.autofocus && i == 0,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          cursorColor: AppColors.black,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontFamily: kFontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: focused ? AppColors.white : AppColors.chip,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: filled ? AppColors.black : AppColors.border,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.black, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          onChanged: (v) => _onChanged(i, v),
        ),
      ),
    );
  }
}
