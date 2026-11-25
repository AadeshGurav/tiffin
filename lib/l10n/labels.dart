import 'package:intl/intl.dart';

import '../core/meal_type.dart';
import '../core/role.dart';
import '../domain/ledger.dart';
import '../domain/member.dart' show UnitCounts;
import '../domain/settings.dart' show AnytimeMeal;
import '../ui/theme/category_palette.dart';
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

  /// Any stored meal id (ADR 0009): a built-in's localised label, else the
  /// admin's name for it in [catalogue], else the raw id — history that
  /// names a meal this phone doesn't know still shows, never crashes.
  String mealName(String id, [List<AnytimeMeal> catalogue = const []]) {
    if (MealType.tryWire(id) case final m?) return mealLabel(m);
    for (final a in catalogue) {
      if (a.id == id) return a.name;
    }
    return id;
  }

  /// One "Tea 5" per non-zero meal in [units] — every meal, or with
  /// [anytimeOnly] just the anytime ones — joined with " · "; '' when none.
  String unitsLine(UnitCounts units, List<AnytimeMeal> catalogue,
          {bool anytimeOnly = false}) =>
      [
        for (final e in units.byMeal.entries)
          if (!anytimeOnly || MealType.tryWire(e.key) == null)
            mealUnits(mealName(e.key, catalogue), e.value),
      ].join(' · ');

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
        'pending' => statusPending,
        _ => status,
      };

  String categoryColorName(CategoryColor c) => switch (c) {
        CategoryColor.red => categoryColorRed,
        CategoryColor.orange => categoryColorOrange,
        CategoryColor.olive => categoryColorOlive,
        CategoryColor.green => categoryColorGreen,
        CategoryColor.teal => categoryColorTeal,
        CategoryColor.blue => categoryColorBlue,
        CategoryColor.indigo => categoryColorIndigo,
        CategoryColor.purple => categoryColorPurple,
        CategoryColor.pink => categoryColorPink,
        CategoryColor.slate => categoryColorSlate,
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
