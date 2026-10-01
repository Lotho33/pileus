import 'package:flutter/services.dart';

/// Forces every keystroke to uppercase — unlike `TextCapitalization.
/// characters` (a soft-keyboard *hint* the IME is free to ignore, and a
/// no-op for a physical/Bluetooth keyboard), this actually rewrites the
/// value, so mixed-case input can never land in the field. For the pairing
/// code field (mobile/desktop): the server treats the code
/// case-sensitively as typed, and every other entry path (TV's on-screen
/// keyboard, the server's own admin dashboard) already only ever produces
/// uppercase — this keeps the system-keyboard path consistent with those
/// instead of being the one way to accidentally type a code that looks
/// right but never matches.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
