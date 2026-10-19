import 'package:intl/intl.dart';

import '../core/meal_type.dart';
import '../core/role.dart';
import '../domain/ledger.dart';
import '../ui/theme/theme_catalog.dart';
import 'app_localizations.dart';

/// Words for the values the app stores in English wire form (`lunch`,
/// `admin`, `pending`), so no screen, report or bill ever shows a raw enum.
/// One place, so a meal is called the same thing everywhere (CLAUDE.md §13).
extension AppTextLabels on AppText {
  String mealLabel(MealType meal) => switch (meal) {
        MealType.breakfast => mealBreakfast,
        MealType.lunch => mealLunch,
        MealType.brunch => mealBrunch,
      };

  /// For wire strings read back from storage; unknown values pass through.
  String mealWire(String wire) {
    for (final m in MealType.values) {
      if (m.wire == wire) return mealLabel(m);
    }
    return wire;
  }

  String roleLabel(Role role) => switch (role) {
        Role.admin => roleAdmin,
        Role.counter => roleCounter,
        Role.scanner => roleScanner,
      };

  String memberTypeLabel(String type) => switch (type) {
        'student' => memberTypeStudent,
        'staff' => memberTypeStaff,
        _ => type,
      };

  String statusLabel(String status) => switch (status) {
        'active' => statusActive,
        'inactive' => statusInactive,
        _ => status,
      };

  String paymentMethodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => paymentCash,
        PaymentMethod.upi => paymentUpi,
      };

  String paymentStatusLabel(String status) => switch (status) {
        'pending' => paymentPending,
        'confirmed' => paymentConfirmed,
        _ => status,
      };

  String yesNo(bool value) => value ? commonYes : commonNo;

  String themeLabel(TiffinThemeId id) => switch (id) {
        TiffinThemeId.neobrutal => themeNeobrutalLabel,
        TiffinThemeId.clean => themeCleanLabel,
        TiffinThemeId.frost => themeFrostLabel,
        TiffinThemeId.clay => themeClayLabel,
      };

  String themeBlurb(TiffinThemeId id) => switch (id) {
        TiffinThemeId.neobrutal => themeNeobrutalBlurb,
        TiffinThemeId.clean => themeCleanBlurb,
        TiffinThemeId.frost => themeFrostBlurb,
        TiffinThemeId.clay => themeClayBlurb,
      };

  /// Known units get a translated name; anything an admin typed is theirs and
  /// is shown as typed.
  String unitLabel(String unit) => switch (unit) {
        'kg' => unitKg,
        'g' => unitG,
        'litre' => unitLitre,
        'ml' => unitMl,
        'pcs' => unitPcs,
        'packet' => unitPacket,
        'dozen' => unitDozen,
        'bunch' => unitBunch,
        'bottle' => unitBottle,
        'can' => unitCan,
        'box' => unitBox,
        _ => unit,
      };

  /// Rupees with Indian digit grouping (₹1,00,000.00), in every language.
  ///
  /// Always `en_IN` digits on purpose: CLDR gives Marathi Devanagari digits by
  /// default, while every count the ARB files interpolate is Latin — mixing
  /// the two on one screen is worse than either. Hindi already uses Latin
  /// digits with this grouping.
  String money(double amount) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
          .format(amount);

  /// A plain number in the same grouping, without a currency sign.
  String number(num value) =>
      NumberFormat.decimalPattern('en_IN').format(value);
}

/// A record id short enough to read aloud or match by eye ("3F9A2C").
/// Firestore ids are 20 characters, which nobody compares across two phones.
String shortCode(String id) =>
    (id.length <= 6 ? id : id.substring(0, 6)).toUpperCase();
