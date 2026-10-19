/// Typed application errors shared by every layer.
///
/// A failure carries *what* went wrong as a specific [ErrorCode] plus the
/// values a sentence about it needs ([args]) — never prose. The UI turns the
/// code into a sentence in the operator's language (`localizeError` in
/// `ui/shared_widgets/nb_feedback.dart`), so a service never has to know which
/// language the person holding the phone reads (CLAUDE.md §8, §13).
library;

/// Every expected, explainable failure. Grouped by the domain that raises it.
enum ErrorCode {
  // auth & accounts
  badCredentials,
  notSignedIn,
  roleNotAllowedOnDevice,
  alreadySetUp,
  usernameRequired,
  usernameLength,
  usernameChars,
  usernameTaken,
  passwordTooShort,
  cannotDeactivateSelf,
  cannotDeleteSelf,
  noSuchAccount,
  userNotFound,
  onlineAccountsDisabled,

  // devices & firebase
  deviceNotApproved,
  needsInternet,
  permissionDenied,
  firebaseConfigUnreadable,
  firebaseConfigWrongApp,

  // members
  memberNotFound,
  memberStudentHasStaffId,
  memberStaffHasClass,
  memberUnknownType,
  memberHasHistory,

  // top-ups & refunds
  topupNeedsUnits,
  topupNotFound,
  refundNeedsUnits,
  refundExceedsBalance,

  // menu
  categoryNameBlank,
  categoryExists,
  categoryNotFound,
  unknownCategory,
  menuItemsRequired,
  headcountNegative,
  menuEntryExists,
  menuEntryNotFound,

  // kitchen
  ingredientNameUnitRequired,
  ingredientExists,
  ingredientNotFound,
  nothingToUpdate,
  recipeDishBlank,
  recipeNeedsIngredient,
  recipeQuantityPositive,
  recipeUnknownIngredient,
  recipeExists,
  recipeNotFound,
  purchaseRangeInvalid,
  purchaseQuantityRequired,
  purchaseItemNotFound,
  expenseAmountNegative,

  // settings
  settingsNegative,
  settingsBadTimezone,
  settingsBadTime,
  settingsWindowOrder,
  settingsBlank,

  // notifications
  notificationNotFound,

  // backup & import
  backupUnreadable,
  backupNotTiffin,
  backupNeedsPassphrase,
  backupWrongPassphrase,
  backupNewerVersion,
  backupTargetNotEmpty,

  // anything else
  internal,
}

/// Base class for every expected, explainable failure in the system.
///
/// [message] is for logs only — English, with the args inlined. Users see
/// [code] rendered through the ARB files.
sealed class AppException implements Exception {
  const AppException(this.code, [this.args = const {}]);

  final ErrorCode code;
  final Map<String, Object> args;

  String get message => args.isEmpty ? code.name : '${code.name} $args';

  @override
  String toString() => '$runtimeType($message)';
}

/// Input failed a business or schema rule.
class ValidationException extends AppException {
  const ValidationException(super.code, [super.args]);
}

/// The requested record does not exist.
class NotFoundException extends AppException {
  const NotFoundException(super.code, [super.args]);
}

/// The action conflicts with current state (duplicate name, member with
/// history that can't be deleted).
class ConflictException extends AppException {
  const ConflictException(super.code, [super.args]);
}

/// No valid session, or the credentials were wrong.
class AuthException extends AppException {
  const AuthException(super.code, [super.args]);
}

/// Signed in, but this role or this device may not do it.
class ForbiddenException extends AppException {
  const ForbiddenException(super.code, [super.args]);
}

/// A dependency that isn't business logic failed in a way the caller can't
/// fix (PDF engine, filesystem). The detail goes to the log.
class InternalException extends AppException {
  const InternalException() : super(ErrorCode.internal);
}
