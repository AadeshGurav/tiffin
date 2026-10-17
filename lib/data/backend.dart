import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../core/meal_type.dart';
import '../core/role.dart';
import '../core/sentinels.dart';
import '../domain/inventory.dart';
import '../domain/ledger.dart';
import '../domain/member.dart';
import '../domain/menu.dart';
import '../domain/ops.dart';
import '../domain/settings.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/billing_service.dart';
import '../services/expense_service.dart';
import '../services/ingredient_service.dart';
import '../services/member_service.dart';
import '../services/menu_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_schedule_service.dart';
import '../services/qr_service.dart';
import '../services/recipe_service.dart';
import '../services/refund_service.dart';
import '../services/report_service.dart';
import '../services/scan_service.dart';
import '../services/settings_service.dart';
import '../services/topup_service.dart';
import '../services/user_service.dart';
import '../ui/theme/appearance.dart';
import 'store.dart';

export '../services/settings_service.dart' show SettingsPatch;

/// The one data-access seam every screen depends on (PRD §13.7). It owns the
/// services, knows who is signed in on this phone, and stamps that name on
/// what they record (createdBy / processedBy / reversedBy).
///
/// There used to be two implementations — in-process for the LAN host, HTTP
/// for its clients. With every phone talking to Firestore directly there is
/// one, so this is a class, not an interface.
class Backend {
  /// [deviceRole] caps which offline accounts may sign in here: null for a
  /// phone signed in with an online account, where the account's own role
  /// applies and there is no offline sign-in. [scratch] is where a legacy
  /// backup's SQLite file is unpacked.
  Backend(this.store, this._prefs,
      {required this.deviceRole, required Directory scratch})
      : qr = QrService(),
        billing = BillingService() {
    backups = BackupService(store,
        appVersion: AppConfig.appVersion, workingDirectory: scratch);
    settings = SettingsService(store);
    auth = AuthService(store, _prefs, sessionTtl: const Duration(hours: 12));
    expenses = ExpenseService(store);
    notifications = NotificationService(store, settings);
    members = MemberService(store, qr);
    scans = ScanService(store, settings, notifications);
    topups = TopupService(store, settings, billing, qr);
    refunds = RefundService(store, settings);
    menu = MenuService(store);
    users = UserService(store, auth);
    ingredients = IngredientService(store);
    recipes = RecipeService(store);
    purchaseSchedule = PurchaseScheduleService(store);
    reports = ReportService(store, settings, expenses);
  }

  final Store store;
  final SharedPreferences _prefs;
  final Role? deviceRole;
  final QrService qr;
  final BillingService billing;
  late final SettingsService settings;
  late final AuthService auth;
  late final ExpenseService expenses;
  late final NotificationService notifications;
  late final MemberService members;
  late final ScanService scans;
  late final TopupService topups;
  late final RefundService refunds;
  late final MenuService menu;
  late final UserService users;
  late final IngredientService ingredients;
  late final RecipeService recipes;
  late final PurchaseScheduleService purchaseSchedule;
  late final ReportService reports;
  late final BackupService backups;

  LocalSession? _session;
  AuthSession? _online;

  String get _username => _session?.username ?? _online?.username ?? '?';
  Role get _role => _session?.role ?? _online?.role ?? Role.scanner;

  void _requireSession() {
    if (_session == null && _online == null) {
      throw const AuthException(ErrorCode.notSignedIn);
    }
  }

  // ---- auth ---------------------------------------------------------

  /// Offline-account sign-in, checked on this phone against the synced
  /// accounts. Works with no network.
  Future<AuthSession> login(String username, String password) async {
    final user = await auth.authenticate(username, password);
    if (user == null) throw const AuthException(ErrorCode.badCredentials);
    final role = Role.fromWire(user['role'] as String);
    final cap = deviceRole;
    // Role enum is ordered widest → narrowest, so a narrower-or-equal role
    // has an index at least the phone's.
    if (cap != null && role.index < cap.index) {
      throw ForbiddenException(ErrorCode.roleNotAllowedOnDevice,
          {'deviceRole': cap.wire, 'role': role.wire});
    }
    final session = await auth.createSession(user);
    _session = session;
    return AuthSession(
        token: session.token, username: session.username, role: role);
  }

  /// An online account is signed in by Firebase Auth itself; this records it
  /// as the acting person.
  AuthSession adoptOnline(String email, Role role) =>
      _online = AuthSession(token: 'online', username: email, role: role);

  Future<void> logout() async {
    final token = _session?.token;
    _session = null;
    _online = null;
    if (token != null) await auth.deleteSession(token);
  }

  /// Re-establishes a session this phone saved earlier, or null when it has
  /// expired or the account was turned off.
  Future<AuthSession?> resumeSession(String token) async {
    try {
      final s = await auth.requireSession(token);
      _session = s;
      return AuthSession(token: s.token, username: s.username, role: s.role);
    } on AppException {
      return null;
    }
  }

  bool get needsOfflineSignIn => deviceRole != null;

  // ---- settings ---------------------------------------------------

  Future<String> branding() => settings.readAppName();

  /// Who this canteen is and how it wants to look — readable before sign-in.
  Future<HostGreeting> greeting() async {
    final s = await settings.read();
    return HostGreeting.fromWire(
        {...s.toAppearanceJson(), 'hostId': store.db.app.options.projectId});
  }

  Future<SettingsSnapshot> getSettings() => settings.read();
  Future<List<String>> timezones() async => settings.availableTimezones();
  Future<SettingsSnapshot> updateSettings(SettingsPatch patch) =>
      settings.update(patch);
  Future<bool> onlineAccountsEnabled() => settings.onlineAccountsEnabled();
  Future<void> setOnlineAccountsEnabled(bool on) =>
      settings.setOnlineAccountsEnabled(on);

  // ---- members --------------------------------------------------

  Future<List<Member>> listMembers({String? type, String? status}) =>
      members.list(type: type, status: status);
  Future<Member> getMember(String id) => members.getById(id);
  Future<Member> createMember(MemberDraft draft) => members.create(draft);
  Future<BulkResult> bulkCreateMembers(List<MemberDraft> drafts) =>
      members.createBulk(drafts);
  Future<Member> updateMember(String id, MemberPatch patch) =>
      members.update(id, patch);
  Future<void> deleteMember(String id) => members.delete(id);
  Future<Member> creditMember(String id, UnitCounts units) =>
      members.credit(id, units);
  Future<List<int>> memberQrPng(String id) => members.renderQr(id);

  // ---- scanning ----------------------------------------------

  Future<ScanResult> scan(String qrCodeId, {MealType? mealTypeOverride}) =>
      scans.processScan(qrCodeId, mealTypeOverride: mealTypeOverride);

  Future<ReversalResult> reverseScan(String scanId) {
    _requireSession();
    return scans.reverseScan(scanId, _username);
  }

  Future<List<ScanRecord>> recentScans({String? memberId, int limit = 200}) =>
      scans.recentScans(memberId: memberId, limit: limit);

  // ---- top-ups ---------------------------------------------

  Future<List<Topup>> listTopups({String? memberId, int limit = 200}) =>
      topups.list(memberId: memberId, limit: limit);

  Future<Topup> createTopup(TopupDraft draft) {
    _requireSession();
    return topups.create(TopupDraft(
      memberId: draft.memberId,
      lunchUnits: draft.lunchUnits,
      breakfastUnits: draft.breakfastUnits,
      brunchUnits: draft.brunchUnits,
      paymentMethod: draft.paymentMethod,
      createdBy: _username,
    ));
  }

  Future<void> confirmTopupPayment(String id) => topups.confirmPayment(id);

  Future<ReversalResult> reverseTopup(String id) {
    _requireSession();
    return topups.reverse(id, _username);
  }

  Future<List<int>> topupUpiQrPng(String id) => topups.upiQr(id);

  // ---- refunds -------------------------------------------

  Future<List<Refund>> listRefunds({String? memberId}) =>
      refunds.list(memberId: memberId);

  Future<Refund> createRefund(RefundDraft draft) {
    _requireSession();
    return refunds.create(RefundDraft(
      memberId: draft.memberId,
      lunchUnits: draft.lunchUnits,
      breakfastUnits: draft.breakfastUnits,
      brunchUnits: draft.brunchUnits,
      reason: draft.reason,
      processedBy: _username,
    ));
  }

  // ---- menu -------------------------------------------

  Future<List<MenuCategory>> listMenuCategories() => menu.listCategories();
  Future<MenuCategory> createMenuCategory(String name, String? description) =>
      menu.createCategory(name, description);
  Future<MenuCategory> updateMenuCategory(String id,
          {String? name, Object? description = kUnset}) =>
      menu.updateCategory(id, name: name, description: description);
  Future<void> deleteMenuCategory(String id) => menu.deleteCategory(id);
  Future<List<MenuEntry>> listMenu({DateTime? start, DateTime? end}) =>
      menu.listEntries(start: start, end: end);

  Future<MenuEntry> addMenuEntry(MenuEntryDraft draft) {
    _requireSession();
    return menu.addEntry(MenuEntryDraft(
      date: draft.date,
      mealType: draft.mealType,
      category: draft.category,
      headcount: draft.headcount,
      items: draft.items,
      createdBy: _username,
    ));
  }

  Future<MenuEntry> updateMenuEntry(String id,
          {List<String>? items, int? headcount}) =>
      menu.updateEntry(id, items: items, headcount: headcount);
  Future<void> deleteMenuEntry(String id) => menu.deleteEntry(id);

  // ---- ingredients & recipes ----------------------------

  Future<List<Ingredient>> listIngredients() => ingredients.list();
  Future<Ingredient> createIngredient(String name, String unit,
          {double stockQty = 0, double? lowStockAt}) =>
      ingredients.create(name, unit,
          stockQty: stockQty, lowStockAt: lowStockAt);
  Future<Ingredient> updateIngredient(String id,
          {String? name,
          String? unit,
          double? stockQty,
          Object? lowStockAt = kUnset}) =>
      ingredients.update(id,
          name: name, unit: unit, stockQty: stockQty, lowStockAt: lowStockAt);
  Future<Ingredient> adjustIngredientStock(
          String id, double delta, String reason) =>
      ingredients.adjustStock(id, delta, reason);
  Future<void> deleteIngredient(String id) => ingredients.delete(id);
  Future<List<Recipe>> listRecipes() => recipes.list();
  Future<Recipe> createRecipe(RecipeDraft draft) => recipes.create(draft);
  Future<Recipe> updateRecipe(String id,
          {String? dishName, List<RecipeIngredient>? ingredients}) =>
      recipes.update(id, dishName: dishName, ingredients: ingredients);
  Future<void> deleteRecipe(String id) => recipes.delete(id);

  // ---- purchase schedule ----------------------------

  Future<int> generatePurchaseSchedule(DateTime start, DateTime end) =>
      purchaseSchedule.generate(start, end);
  Future<List<PurchaseScheduleItem>> listPurchaseSchedule(
          {DateTime? start, DateTime? end}) =>
      purchaseSchedule.list(start: start, end: end);
  Future<PurchaseScheduleItem> addManualPurchaseItem(
          DateTime date, String ingredientId, String quantityNote) =>
      purchaseSchedule.addManual(date, ingredientId, quantityNote);

  Future<PurchaseScheduleItem> updatePurchaseItem(String id,
      {String? quantityNote,
      bool? purchased,
      double? purchasedQty,
      double? purchasedCost}) {
    _requireSession();
    return purchaseSchedule.updateItem(
      id,
      quantityNote: quantityNote,
      purchased: purchased,
      purchasedQty: purchasedQty,
      purchasedCost: purchasedCost,
      actingUsername: _username,
    );
  }

  Future<void> deletePurchaseItem(String id) => purchaseSchedule.deleteItem(id);

  // ---- expenses ---------------------------------

  Future<List<Expense>> listExpenses({DateTime? start, DateTime? end}) =>
      expenses.list(start: start, end: end);

  Future<Expense> addExpense(ExpenseDraft draft) {
    _requireSession();
    return expenses.add(ExpenseDraft(
      category: draft.category,
      description: draft.description,
      amount: draft.amount,
      date: draft.date,
      createdBy: _username,
    ));
  }

  Future<ProfitSummary> profitSummary({DateTime? start, DateTime? end}) =>
      expenses.summary(start: start, end: end);

  // ---- users ---------------------------------

  Future<List<AppUser>> listUsers() => users.list();
  Future<AppUser> createUser(UserDraft draft) => users.create(draft);

  Future<AppUser> updateUser(String id, UserPatch patch) {
    _requireSession();
    return users.update(id, patch, actingUserId: _session?.userId ?? '');
  }

  Future<void> deleteUser(String id) {
    _requireSession();
    return users.delete(id, actingUserId: _session?.userId ?? '');
  }

  // ---- notifications ------------------------

  Future<List<AppNotification>> listNotifications() async {
    _requireSession();
    await notifications.generateDue(DateTime.now().toUtc());
    return notifications.listFor(_role, _username);
  }

  Future<void> dismissNotification(String id) {
    _requireSession();
    return notifications.dismiss(id, _username);
  }

  // ---- reports & backup ------------------------

  Future<List<int>> buildReport(AppText t,
          {DateTime? start, DateTime? end, Set<ReportSection>? sections}) =>
      reports.build(
          t: t,
          start: start,
          end: end,
          sections: sections ?? ReportSection.all);
}
