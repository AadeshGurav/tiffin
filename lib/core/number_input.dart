import 'errors.dart';

/// Reads a whole number a person typed. Blank means [ifBlank] (an empty units
/// box is "none"); anything else that isn't a number is refused rather than
/// quietly saved as 0 — a mistyped price must not become a free meal.
int parseWholeNumber(String text, {int ifBlank = 0}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return ifBlank;
  return int.tryParse(trimmed) ??
      (throw const ValidationException(ErrorCode.numberInvalid));
}

/// Like [parseWholeNumber] for money and quantities. A decimal comma is
/// accepted: `12,5` is a normal way to type it (Postel's Law).
double parseAmount(String text, {double ifBlank = 0}) {
  final trimmed = text.trim().replaceFirst(',', '.');
  if (trimmed.isEmpty) return ifBlank;
  final value = double.tryParse(trimmed);
  if (value == null || !value.isFinite) {
    throw const ValidationException(ErrorCode.numberInvalid);
  }
  return value;
}
