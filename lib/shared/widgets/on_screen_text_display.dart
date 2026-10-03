import 'package:flutter/material.dart';

/// Looks like a text field, isn't one.
///
/// Every field paired with `OnScreenKeyboard` used to be a real `TextField`
/// with `readOnly: true` + `keyboardType: TextInputType.none` — intended to
/// make a platform/browser IME impossible, since input always comes from
/// `OnScreenKeyboard` writing straight into [controller], never from
/// focusing this and typing. That held on native (Android TV) but not on
/// web: Flutter's web engine creates a real, focusable `<input>`/
/// `<textarea>` DOM element under any `EditableText` to support browser
/// autofill/IME composition, and `inputmode="none"` isn't reliably honored
/// by every embedded browser engine — confirmed on webOS, where a platform
/// keyboard still popped up and stole focus despite both properties being
/// set correctly.
///
/// This renders the identical look with a plain [Text] instead — no
/// `EditableText`, so no DOM input for a browser to attach an IME to, on
/// any platform. `focusNode` still makes this a normal D-pad navigation
/// target via the ambient [Focus] it wraps.
class OnScreenTextDisplay extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle style;
  final TextStyle? hintStyle;
  final bool obscureText;
  final EdgeInsetsGeometry contentPadding;
  final Color fillColor;
  final Color borderColor;
  final double borderRadius;
  final TextAlign textAlign;

  const OnScreenTextDisplay({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    required this.style,
    this.hintStyle,
    this.obscureText = false,
    required this.contentPadding,
    required this.fillColor,
    required this.borderColor,
    this.borderRadius = 12,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final text = controller.text;
          final isEmpty = text.isEmpty;
          final display = obscureText ? '•' * text.length : text;
          return Container(
            padding: contentPadding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              isEmpty ? (hintText ?? '') : display,
              style: isEmpty ? (hintStyle ?? style) : style,
              textAlign: textAlign,
            ),
          );
        },
      ),
    );
  }
}
