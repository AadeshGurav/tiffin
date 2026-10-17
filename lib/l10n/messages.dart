import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/errors.dart';
import '../core/role.dart';
import '../domain/ledger.dart';
import '../domain/ops.dart';
import 'app_localizations.dart';
import 'labels.dart';

/// Turns the app's codes into sentences. Services return *what happened*;
/// this is the one place that says it, so every screen words the same failure
/// the same way, in the operator's language (CLAUDE.md §8, §13).
extension AppTextMessages on AppText {
  /// Any error a screen might catch — the app's own, Firestore's, Firebase
  /// Auth's — as one readable sentence. Never a stack trace or raw exception
  /// text; anything unrecognised gets a plain "written to the log".
  String errorText(Object error) => switch (error) {
        AppException e => _appError(e),
        FirebaseAuthException e => _authError(e.code),
        FirebaseException e => _firestoreError(e.code),
        _ => errUnexpected,
      };

  String _firestoreError(String code) => switch (code) {
        'permission-denied' => errPermissionDenied,
        'unavailable' || 'deadline-exceeded' => errNeedsInternet,
        _ => errUnexpected,
      };

  String _authError(String code) => switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' =>
          errBadCredentials,
        'network-request-failed' => errNeedsInternet,
        'email-already-in-use' => errEmailInUse,
        'weak-password' => errPasswordTooShort(6),
        _ => errUnexpected,
      };

  String _appError(AppException e) {
    String s(String k) => '${e.args[k] ?? ''}';
    int n(String k) => (e.args[k] as num?)?.toInt() ?? 0;
    String meal(String k) => mealWire(s(k));
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
      ErrorCode.firebaseConfigUnreadable => errFirebaseConfigUnreadable,
      ErrorCode.firebaseConfigWrongApp => errFirebaseConfigWrongApp(s('appId')),
      ErrorCode.memberNotFound => errMemberNotFound,
      ErrorCode.memberStudentHasStaffId => errMemberStudentHasStaffId,
      ErrorCode.memberStaffHasClass => errMemberStaffHasClass,
      ErrorCode.memberUnknownType => errMemberUnknownType(s('type')),
      ErrorCode.memberHasHistory => errMemberHasHistory,
      ErrorCode.topupNeedsUnits => errTopupNeedsUnits,
      ErrorCode.topupNotFound => errTopupNotFound,
      ErrorCode.refundNeedsUnits => errRefundNeedsUnits,
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
      ErrorCode.settingsNegative => errSettingsNegative,
      ErrorCode.settingsBadTimezone => errSettingsBadTimezone(s('name')),
      ErrorCode.settingsBadTime => errSettingsBadTime(meal('meal')),
      ErrorCode.settingsWindowOrder =>
        errSettingsWindowOrder(meal('meal'), s('start'), s('end')),
      ErrorCode.settingsBlank => errSettingsBlank,
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

  String reversalText(ReversalResult r) {
    final meal = r.mealType == null ? '' : mealLabel(r.mealType!);
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
  String scanText(ScanResult r) {
    final name = r.memberName ?? '';
    final meal = r.mealType == null ? '' : mealLabel(r.mealType!);
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
    String meal(String k) => mealWire(s(k));
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
