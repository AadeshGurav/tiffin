import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

import '../core/error_report.dart';
import '../core/errors.dart';
import '../core/role.dart';
import '../domain/ledger.dart';
import '../domain/ops.dart';
import '../domain/settings.dart' show AnytimeMeal;
import 'app_localizations.dart';
import 'labels.dart';

final _expected = Logger('error');

/// Turns the app's codes into sentences. Services return *what happened*;
/// this is the one place that says it, so every screen words the same failure
/// the same way, in the operator's language (CLAUDE.md §8, §13).
extension AppTextMessages on AppText {
  /// Any error a screen might catch — the app's own, Firestore's, Firebase
  /// Auth's — as one readable sentence. Never a stack trace or raw exception
  /// text. Prefer [describeError], which also logs what nobody anticipated.
  String errorText(Object error) =>
      _knownText(error) ??
      (error is AppException ? errInternal : errUnexpected);

  /// The one way a screen turns a caught failure into something to show.
  /// An anticipated failure is a plain sentence. An unanticipated one is
  /// logged in full under a fresh reference code, which rides along so the
  /// person can hand it to IT (see docs/ERRORS.md).
  ErrorNotice describeError(Object error, [StackTrace? stack]) {
    final known = _knownText(error);
    if (known != null) {
      // Worth a trace in the log (a refused write, a dropped connection) but
      // nothing the person needs to report.
      if (error is! AppException) {
        _expected.warning('${error.runtimeType}: $error');
      }
      return ErrorNotice(known);
    }
    return ErrorNotice(errorText(error), ref: reportError(error, stack));
  }

  /// Null for anything that has no sentence of its own.
  String? _knownText(Object error) => switch (error) {
        AppException(code: ErrorCode.internal) => null,
        AppException e => _appError(e),
        FirebaseAuthException e => _authError(e.code),
        FirebaseException e => _firestoreError(e.code),
        _ => null,
      };

  String? _firestoreError(String code) => switch (code) {
        'permission-denied' => errPermissionDenied,
        'unavailable' || 'deadline-exceeded' => errNeedsInternet,
        _ => null,
      };

  String? _authError(String code) => switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' =>
          errBadCredentials,
        'network-request-failed' => errNeedsInternet,
        'account-exists-with-different-credential' => errAccountOtherMethod,
        'credential-already-in-use' => errAccountOtherMethod,
        'operation-not-allowed' ||
        'admin-restricted-operation' =>
          errSignInMethodOff,
        'provider-already-linked' => errMethodAlreadyAdded,
        'email-already-in-use' => errEmailInUse,
        'weak-password' => errPasswordTooShort(6),
        _ => null,
      };

  String _appError(AppException e) {
    String s(String k) => '${e.args[k] ?? ''}';
    int n(String k) => (e.args[k] as num?)?.toInt() ?? 0;
    String meal(String k) => mealName(s(k));
    String role(String k) {
      try {
        return roleLabel(Role.fromWire(s(k)));
      } on ArgumentError {
        return s(k);
      }
    }

    return switch (e.code) {
      ErrorCode.badCredentials => errBadCredentials,
      ErrorCode.notSignedIn => errNotSignedIn,
      ErrorCode.roleNotAllowedOnDevice =>
        errRoleNotAllowedOnDevice(role('deviceRole'), role('role')),
      ErrorCode.alreadySetUp => errAlreadySetUp,
      ErrorCode.usernameRequired => errUsernameRequired,
      ErrorCode.usernameLength => errUsernameLength,
      ErrorCode.usernameChars => errUsernameChars,
      ErrorCode.usernameTaken => errUsernameTaken(s('name')),
      ErrorCode.passwordTooShort => errPasswordTooShort(n('min')),
      ErrorCode.cannotDeactivateSelf => errCannotDeactivateSelf,
      ErrorCode.cannotDeleteSelf => errCannotDeleteSelf,
      ErrorCode.noSuchAccount => errNoSuchAccount(s('name')),
      ErrorCode.userNotFound => errUserNotFound,
      ErrorCode.onlineAccountsDisabled => errOnlineAccountsDisabled,
      ErrorCode.deviceNotApproved => errDeviceNotApproved,
      ErrorCode.needsInternet => errNeedsInternet,
      ErrorCode.permissionDenied => errPermissionDenied,
      ErrorCode.canteenNotFound => errCanteenNotFound,
      ErrorCode.signInRequired => errSignInRequired,
      ErrorCode.memberNotFound => errMemberNotFound,
      ErrorCode.memberStudentHasStaffId => errMemberStudentHasStaffId,
      ErrorCode.memberStaffHasClass => errMemberStaffHasClass,
      ErrorCode.memberUnknownType => errMemberUnknownType(s('type')),
      ErrorCode.memberHasHistory => errMemberHasHistory,
      ErrorCode.topupNeedsUnits => errTopupNeedsUnits,
      ErrorCode.topupNotFound => errTopupNotFound,
      ErrorCode.refundNeedsUnits => errRefundNeedsUnits,
      ErrorCode.negativeUnits => errNegativeUnits,
      ErrorCode.refundExceedsBalance =>
        errRefundExceedsBalance(n('requested'), meal('meal'), n('available')),
      ErrorCode.categoryNameBlank => errCategoryNameBlank,
      ErrorCode.categoryExists => errCategoryExists(s('name')),
      ErrorCode.categoryNotFound => errCategoryNotFound,
      ErrorCode.unknownCategory => errUnknownCategory(s('name')),
      ErrorCode.menuItemsRequired => errMenuItemsRequired,
      ErrorCode.headcountNegative => errHeadcountNegative,
      ErrorCode.menuEntryExists =>
        errMenuEntryExists(meal('meal'), s('category')),
      ErrorCode.menuEntryNotFound => errMenuEntryNotFound,
      ErrorCode.ingredientNameUnitRequired => errIngredientNameUnitRequired,
      ErrorCode.ingredientExists => errIngredientExists(s('name')),
      ErrorCode.ingredientNotFound => errIngredientNotFound,
      ErrorCode.nothingToUpdate => errNothingToUpdate,
      ErrorCode.recipeDishBlank => errRecipeDishBlank,
      ErrorCode.recipeNeedsIngredient => errRecipeNeedsIngredient,
      ErrorCode.recipeQuantityPositive => errRecipeQuantityPositive,
      ErrorCode.recipeUnknownIngredient => errRecipeUnknownIngredient,
      ErrorCode.recipeExists => errRecipeExists(s('name')),
      ErrorCode.recipeNotFound => errRecipeNotFound,
      ErrorCode.purchaseRangeInvalid => errPurchaseRangeInvalid,
      ErrorCode.purchaseQuantityRequired => errPurchaseQuantityRequired,
      ErrorCode.purchaseItemNotFound => errPurchaseItemNotFound,
      ErrorCode.expenseAmountNegative => errExpenseAmountNegative,
      ErrorCode.numberInvalid => errNumberInvalid,
      ErrorCode.settingsNegative => errSettingsNegative,
      ErrorCode.settingsBadTimezone => errSettingsBadTimezone(s('name')),
      ErrorCode.settingsBadTime => errSettingsBadTime(meal('meal')),
      ErrorCode.settingsWindowOrder =>
        errSettingsWindowOrder(meal('meal'), s('start'), s('end')),
      ErrorCode.settingsBlank => errSettingsBlank,
      ErrorCode.mealNameBlank => errMealNameBlank,
      ErrorCode.mealNameTaken => errMealNameTaken(s('name')),
      ErrorCode.mealCannotBeRemoved => errMealCannotBeRemoved(s('name')),
      ErrorCode.unknownMeal => errUnknownMeal,
      ErrorCode.notificationNotFound => errNotificationNotFound,
      ErrorCode.backupUnreadable => errBackupUnreadable,
      ErrorCode.backupNotTiffin => errBackupNotTiffin,
      ErrorCode.backupNeedsPassphrase => errBackupNeedsPassphrase,
      ErrorCode.backupWrongPassphrase => errBackupWrongPassphrase,
      ErrorCode.backupNewerVersion => errBackupNewerVersion,
      ErrorCode.backupTargetNotEmpty => errBackupTargetNotEmpty,
      ErrorCode.internal => errInternal,
    };
  }

  String reversalText(ReversalResult r,
      {List<AnytimeMeal> catalogue = const []}) {
    final meal = r.meal == null ? '' : mealName(r.meal!, catalogue);
    return switch (r.code) {
      ReversalCode.scanReversed => reversalScanReversed(meal, r.restored ?? 0),
      ReversalCode.scanNotFound => reversalScanNotFound,
      ReversalCode.scanAlreadyReversed => reversalScanAlreadyReversed,
      ReversalCode.scanWindowExpired =>
        reversalScanWindowExpired(r.windowMinutes ?? 0),
      ReversalCode.topupReversed => reversalTopupReversed,
      ReversalCode.topupNotFound => reversalTopupNotFound,
      ReversalCode.topupAlreadyReversed => reversalTopupAlreadyReversed,
      ReversalCode.topupUnitsUsed => reversalTopupUnitsUsed,
      ReversalCode.memberNotFound => reversalMemberNotFound,
    };
  }

  /// The scanner's verdict as one sentence (the big result panel words it).
  String scanText(ScanResult r, {List<AnytimeMeal> catalogue = const []}) {
    final name = r.memberName ?? '';
    final meal = r.meal == null ? '' : mealName(r.meal!, catalogue);
    return switch (r.outcome) {
      // The grace allowance gets its own badge on the result panel.
      ScanOutcome.accepted => scanAccepted(name, meal, r.remainingBalance ?? 0),
      ScanOutcome.rejectedUnknownCode => scanUnknownCode,
      ScanOutcome.rejectedInactive => scanInactive,
      ScanOutcome.rejectedNoMealWindow => scanNoWindow,
      ScanOutcome.rejectedAlreadyScanned => scanAlreadyDone(name, meal),
      ScanOutcome.rejectedZeroBalance => scanNoUnits(name, meal),
    };
  }

  ({String title, String body}) notificationText(AppNotification n) {
    final p = n.params;
    String s(String k) => '${p[k] ?? ''}';
    int i(String k) => (p[k] as num?)?.toInt() ?? 0;
    String q(String k) => p[k] == null ? '' : number(p[k] as num);
    // An anytime meal's name rides in the params (ADR 0009).
    String meal(String k) => mealName(s(k), [
          if (p['mealName'] case final String name)
            AnytimeMeal(id: s(k), name: name, price: 0),
        ]);
    return switch (n.type) {
      'prep_reminder' => (
          title: notifPrepTitle(meal('meal')),
          body: notifPrepBody(meal('meal'), s('start'), i('minutes')),
        ),
      'purchase_due' => (
          title: notifPurchaseTitle,
          body: notifPurchaseBody(i('count'), s('date')),
        ),
      'low_stock' => (
          title: notifLowStockTitle(s('name')),
          body:
              notifLowStockBody(q('qty'), unitLabel(s('unit')), q('threshold')),
        ),
      'headcount_overrun' => (
          title: notifOverrunTitle(s('category'), meal('meal')),
          body: notifOverrunBody(i('planned'), i('served')),
        ),
      'scan_rejected_on_sync' => (
          title: notifScanRejectedTitle,
          body: notifScanRejectedBody(s('name'), meal('meal'), s('date')),
        ),
      'anytime_scan_rejected_on_sync' => (
          title: notifScanRejectedTitle,
          body:
              notifAnytimeScanRejectedBody(s('name'), meal('meal'), s('date')),
        ),
      _ => (title: notifUnknown, body: ''),
    };
  }
}

/// Typed confirmations accept the word in the operator's language or the
/// English one, so a phone switched to Hindi doesn't strand someone who
/// learned "RESET".
bool confirmWordMatches(String typed, String word, String english) {
  final t = typed.trim().toUpperCase();
  return t == word.toUpperCase() || t == english;
}
