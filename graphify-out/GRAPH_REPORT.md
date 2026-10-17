# Graph Report - canteen-coupon-system  (2026-10-17)

## Corpus Check
- 216 files · ~122,016 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 41 file(s) not represented in the graph (top: .xml 11, (none) 7, .plist 4)

## Summary
- 2252 nodes · 3432 edges · 122 communities (105 shown, 17 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.82)
- Token cost: 163,191 input · 0 output

## Community Hubs (Navigation)
- Backend Seam
- Ledger Models
- Motion & Sync State
- Theme Palettes
- Device Access Model
- Devices & Expenses Screens
- Meal Windows & Cache
- Offline Account Auth
- Backup & Restore
- Feedback Widgets
- Admin Data Screens
- Setup & Appearance Screens
- Firestore Store
- Earlier ADRs (0001-0004)
- Canteen Settings
- Inventory Models
- Member Picker
- Firebase Architecture Docs
- Kitchen Planning Services
- Saved Logins
- Member Model
- Top-ups & Refunds
- Notifications & Legacy Import
- Firebase Config & Providers
- Theme & Motion Tests
- Ops Models
- Kitchen Setup UI
- Member Service
- Menu Screen
- Palette
- Settings Config Screen
- Settings
- Nb Button
- Scanner Screen
- Xlsx Writer
- Motion
- Backup Screen
- Nb Picker
- Appearance
- App Logo
- Package
- Oklch
- Runnertests
- Logging
- Admin Dashboard
- Firebase Config
- Settings Row
- Topup Screen
- Menu
- Errors
- App Shell
- Ingredients Screen
- Ledger Test
- Main
- Login Screen
- Providers
- Report Service
- Appearance Providers
- Bill View
- Menu Service
- App Gate
- Scan Service
- Unit Field
- Host Setup Screen
- Settings Screen
- Messages
- Session Memory
- User Service
- Labels
- Motion
- Appearance Screen
- Nb Text Field
- Reports Screen
- Nb Feedback
- Recipes Screen
- Theme Preview
- Ingredient Service
- Providers
- Online Accounts Screen
- Backup Test
- Motion
- Notice Screen
- Fake Backend
- Locale Store
- Role
- Refunds Screen
- Topup History Screen
- Typography
- Setup Screens Test
- L10N Parity Test
- Appearance Providers
- Credential Store Test
- Config
- Qr Service
- Frosted Panel
- Locale Providers
- Access
- Firebase Config Test
- Mainactivity
- Meal Type
- Session Memory
- Topup Screen
- Bootstrap
- Screen Awake
- Settings Screen
- Providers
- Labels
- Login Screen
- Sentinels
- Billing Service
- 0005-Firebase-Offline-First
- Prd
- Prd
- Settings Service
- Claude
- Readme

## God Nodes (most connected - your core abstractions)
1. `_` - 58 edges
2. `backendProvider` - 55 edges
3. `_` - 35 edges
4. `_` - 30 edges
5. `Store` - 20 edges
6. `sessionProvider` - 17 edges
7. `accessServiceProvider` - 11 edges
8. `sessionMemoryProvider` - 10 edges
9. `_` - 10 edges
10. `ADR 0001 Runtime theming and data portability` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Runtime Firebase config import (FirebaseConfig)` --conceptually_related_to--> `Firebase setup per canteen`  [INFERRED]
  docs/adr/0005-firebase-offline-first.md → README.md
- `Moving a v2 LAN-host canteen across` --conceptually_related_to--> `.tiffin backup (zip + data.json) and LegacyImport`  [INFERRED]
  README.md → docs/adr/0005-firebase-offline-first.md
- `Project layout (lib/app, core, domain, data, services, l10n, ui)` --conceptually_related_to--> `CacheWarmer and Store.cached`  [INFERRED]
  README.md → docs/adr/0005-firebase-offline-first.md
- `Words live in the UI, never in the data` --conceptually_related_to--> `l10n.yaml (AppText from app_en.arb)`  [INFERRED]
  docs/adr/0005-firebase-offline-first.md → l10n.yaml
- `CI workflow (analyze-test, rules-test, build-apk, build-ios)` --references--> `firestore.rules emulator tests`  [INFERRED]
  .github/workflows/ci.yml → tool/rules-test/README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Schema evolution v6-v8** — docs_adr_0002_kitchen_setup_and_numeric_recipe_quantities_schema_v6, docs_adr_0003_member_category_and_per_category_menu_entries_schema_v7, docs_adr_0004_ingredient_inventory_and_alerts_schema_v8 [EXTRACTED 0.95]
- **Offline-first Firestore design** — docs_adr_0005_firebase_offline_first_write_batches, docs_adr_0005_firebase_offline_first_cache_warmer, docs_adr_0005_firebase_offline_first_duplicate_scan_id, firestore_rules [EXTRACTED 1.00]
- **CI quality gates** — github_workflows_ci_pipeline, analysis_options_lints, dart_test_tool_tag, tool_rules_test_readme_rules_tests, l10n_yaml_config [INFERRED 0.85]

## Communities (122 total, 17 thin omitted)

### Community 0 - "Backend Seam"
Cohesion: 0.02
Nodes (87): addExpense, addManualPurchaseItem, addMenuEntry, adjustIngredientStock, adoptOnline, auth, backups, billing (+79 more)

### Community 1 - "Ledger Models"
Cohesion: 0.04
Nodes (50): amount, balancesAfter, breakfastUnits, brunchUnits, code, createdAt, createdBy, fromJson (+42 more)

### Community 2 - "Motion & Sync State"
Cohesion: 0.04
Nodes (37): SyncState, MotionTokens, TiffinPalette, borderBase, borderBold, borderHair, chromeBlur, chromeOpacity (+29 more)

### Community 3 - "Theme Palettes"
Cohesion: 0.04
Nodes (35): base, border, buildTiffinTheme, color, copyWith, motion, _NoTransitionBuilder, reduceTransparency (+27 more)

### Community 4 - "Device Access Model"
Cohesion: 0.05
Nodes (38): account, _app, approve, _auth, canteenExists, claimNewCanteen, code, createOnlineAccount (+30 more)

### Community 5 - "Devices & Expenses Screens"
Cohesion: 0.08
Nodes (26): Device, ProfitSummary, build, _expensesProvider, ExpensesScreen, _form, _stat, _summaryProvider (+18 more)

### Community 6 - "Meal Windows & Cache"
Cohesion: 0.05
Nodes (31): _asMinutes, contains, currentMealType, dayBounds, end, HhMm, hour, isAfter (+23 more)

### Community 7 - "Offline Account Auth"
Cohesion: 0.05
Nodes (37): authenticate, _constantTimeEquals, createInitialAdmin, createSession, deleteSession, expiresAt, fromJson, hashPassword (+29 more)

### Community 8 - "Backup & Restore"
Cohesion: 0.05
Nodes (34): appVersion, BackupContents, BackupService, _batchSize, collections, createdAt, dataEntry, _decrypt (+26 more)

### Community 9 - "Feedback Widgets"
Cohesion: 0.06
Nodes (35): _, actionLabel, build, categories, duration, empty, _emptyCheck, EmptyQuips (+27 more)

### Community 10 - "Admin Data Screens"
Cohesion: 0.07
Nodes (33): backendProvider, login, resumeWithToken, _exportBackup, _restore, _busy, _category, _className (+25 more)

### Community 11 - "Setup & Appearance Screens"
Cohesion: 0.07
Nodes (26): build, _busy, ConnectFirebaseScreen, _ConnectFirebaseScreenState, createState, _error, _pick, _busy (+18 more)

### Community 12 - "Firestore Store"
Cohesion: 0.06
Nodes (32): batch, cached, cachedDoc, Col, commit, data, db, devices (+24 more)

### Community 13 - "Earlier ADRs (0001-0004)"
Cohesion: 0.06
Nodes (10): ADR 0001 Runtime theming and data portability, ADR 0002 Kitchen setup and numeric recipe quantities, ADR 0003 Member category and per-category menu entries, ADR 0004 Ingredient inventory and alerts, Clay theme, Clean theme, Frost theme, Neobrutal theme (+2 more)

### Community 14 - "Canteen Settings"
Cohesion: 0.06
Nodes (31): appearanceMode, appearanceMotion, appearanceTheme, appName, availableTimezones, changedFields, defaults, enforceAppearance (+23 more)

### Community 15 - "Inventory Models"
Cohesion: 0.06
Nodes (31): createdAt, date, dishName, formatQuantity, fromJson, id, ingredientId, ingredientName (+23 more)

### Community 16 - "Member Picker"
Cohesion: 0.06
Nodes (30): _all, build, categories, category, className, contains, _createNew, createState (+22 more)

### Community 17 - "Firebase Architecture Docs"
Cohesion: 0.08
Nodes (30): analysis_options.yaml strict lints, dart_test.yaml tool tag, Approved phones, offline accounts, optional online accounts, ADR 0005 Firebase offline-first, LAN host retired, CacheWarmer and Store.cached, Scan doc id {member}_{day}_{meal} create-only, Runtime Firebase config import (FirebaseConfig), Writes as WriteBatch (Store.commit), FieldValue.increment (+22 more)

### Community 18 - "Kitchen Planning Services"
Cohesion: 0.07
Nodes (26): Store, add, _col, list, _log, _store, summary, addManual (+18 more)

### Community 19 - "Saved Logins"
Cohesion: 0.07
Nodes (27): baseUrl, forgetEverything, forgetHost, forgetLogin, fromJson, hostId, invalidateToken, _key (+19 more)

### Community 20 - "Member Model"
Cohesion: 0.07
Nodes (27): balances, breakfast, brunch, category, className, createdAt, forMeal, fromJson (+19 more)

### Community 21 - "Top-ups & Refunds"
Cohesion: 0.08
Nodes (22): _col, create, list, _log, RefundService, _rejectOverRefund, _settings, _store (+14 more)

### Community 22 - "Notifications & Legacy Import"
Cohesion: 0.07
Nodes (21): Json, collections, _convert, LegacyData, LegacyImport, read, settings, _col (+13 more)

### Community 23 - "Firebase Config & Providers"
Cohesion: 0.08
Nodes (20): FirebaseConfig, app, backend, cacheWarmerProvider, config, db, _emulatorHost, FirebaseConfigController (+12 more)

### Community 24 - "Theme & Motion Tests"
Cohesion: 0.09
Nodes (11): main, render, size, main, resolve, bodyMin, expectContrast, main (+3 more)

### Community 25 - "Ops Models"
Cohesion: 0.07
Nodes (27): amount, AppNotification, AppUser, category, createdAt, createdBy, date, description (+19 more)

### Community 26 - "Kitchen Setup UI"
Cohesion: 0.08
Nodes (17): Ingredient, build, createState, dispose, _onTab, _tabs, _dateRow, _explainEmptyGenerate (+9 more)

### Community 27 - "Member Service"
Cohesion: 0.07
Nodes (26): balanceDelta, BulkFailure, BulkResult, _cleanCategory, _col, create, createBulk, created (+18 more)

### Community 28 - "Menu Screen"
Cohesion: 0.09
Nodes (23): build, _categoriesProvider, _cell, _dateOnly, day, end, entries, entryCountByDay (+15 more)

### Community 29 - "Palette"
Cohesion: 0.08
Nodes (24): accent, accept, border, brightness, ink, inkMuted, isDark, on (+16 more)

### Community 30 - "Settings Config Screen"
Cohesion: 0.09
Nodes (23): _appName, _breakfastPrice, _brunchPrice, build, _busy, _ConfigForm, _ConfigFormState, createState (+15 more)

### Community 31 - "Settings"
Cohesion: 0.08
Nodes (25): appearanceMode, appearanceMotion, appearanceTheme, appName, breakfast, brunch, effectiveGrace, end (+17 more)

### Community 32 - "Nb Button"
Cohesion: 0.09
Nodes (20): background, build, busy, foreground, icon, intensity, label, NbButton (+12 more)

### Community 33 - "Scanner Screen"
Cohesion: 0.09
Nodes (21): ScanResult, _busy, _clear, color, _controller, createState, dispose, _errorMessage (+13 more)

### Community 34 - "Xlsx Writer"
Cohesion: 0.09
Nodes (19): add, build, _columnName, _contentTypes, _escape, headers, name, _rootRels (+11 more)

### Community 35 - "Motion"
Cohesion: 0.09
Nodes (20): _animation, build, child, _controller, createState, curve, delay, dispose (+12 more)

### Community 36 - "Backup Screen"
Cohesion: 0.09
Nodes (22): BackupManifest, backups, BackupScreen, _BackupScreenState, build, _busy, bytes, _confirm (+14 more)

### Community 37 - "Nb Picker"
Cohesion: 0.09
Nodes (22): build, child, createState, dispose, emptyHint, _filter, initState, label (+14 more)

### Community 38 - "Appearance"
Cohesion: 0.09
Nodes (22): appName, brightness, copyWith, defaults, enforced, fromWire, hostId, isIdentified (+14 more)

### Community 39 - "App Logo"
Cohesion: 0.09
Nodes (19): AppLogo, AppWordmark, border, borderWidth, build, CouponPainter, _couponPath, fill (+11 more)

### Community 40 - "Package"
Cohesion: 0.10
Nodes (15): ADR-0005, firebase, @firebase/rules-unit-testing, firebase-tools, description, devDependencies, firebase, @firebase/rules-unit-testing (+7 more)

### Community 41 - "Oklch"
Cohesion: 0.09
Nodes (21): best, bestRatio, c, channel, contrastRatio, darken, darker, _encode (+13 more)

### Community 42 - "Runnertests"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 43 - "Logging"
Cohesion: 0.10
Nodes (11): AppLogger, configure, _configured, dispose, _fileSink, _format, log, _logFile (+3 more)

### Community 44 - "Admin Dashboard"
Cohesion: 0.12
Nodes (4): _Dest, icon, label, tone

### Community 45 - "Firebase Config"
Cohesion: 0.10
Nodes (18): _, androidPackage, clear, demo, FirebaseConfigStore, _fromGoogleServicesJson, fromJson, _fromPlist (+10 more)

### Community 46 - "Settings Row"
Cohesion: 0.11
Nodes (15): BrandSplash, build, message, build, danger, icon, onTap, subtitle (+7 more)

### Community 47 - "Topup Screen"
Cohesion: 0.11
Nodes (16): PaymentMethod, SettingsSnapshot, _amount, _busy, _canSubmit, createState, label, _lunch (+8 more)

### Community 48 - "Menu"
Cohesion: 0.11
Nodes (17): category, createdAt, createdBy, date, description, fromJson, headcount, id (+9 more)

### Community 49 - "Errors"
Cohesion: 0.15
Nodes (13): AppException, args, AuthException, code, ConflictException, ErrorCode, ForbiddenException, InternalException (+5 more)

### Community 50 - "App Shell"
Cohesion: 0.12
Nodes (13): notificationsProvider, syncStateProvider, build, SettingsScreen, actions, build, NbAppBar, _NotificationBell (+5 more)

### Community 51 - "Ingredients Screen"
Cohesion: 0.12
Nodes (17): _adjustStock, build, ingredientsProvider, IngredientsTab, lowAt, name, _num, ok (+9 more)

### Community 52 - "Ledger Test"
Cohesion: 0.12
Nodes (7): Backend, b, main, student, at, main, windows

### Community 53 - "Main"
Cohesion: 0.12
Nodes (8): crash, crashText, details, _FriendlyErrorWidget, main, prefs, priorOnError, text

### Community 54 - "Login Screen"
Cohesion: 0.12
Nodes (14): _busy, _confirm, createState, dispose, _error, initialUsername, LoginScreen, _LoginScreenState (+6 more)

### Community 55 - "Providers"
Cohesion: 0.18
Nodes (16): accessServiceProvider, devicesProvider, sessionProvider, AdminDashboard, build, _MemberTile, build, PurchaseScheduleScreen (+8 more)

### Community 56 - "Report Service"
Cohesion: 0.12
Nodes (13): ExpenseService, all, build, _expenses, fileName, label, _log, menu (+5 more)

### Community 57 - "Appearance Providers"
Cohesion: 0.14
Nodes (14): AppearanceController, appearancePolicyProvider, appearanceStoreProvider, build, device, _save, setMode, setMotion (+6 more)

### Community 58 - "Bill View"
Cohesion: 0.12
Nodes (13): Topup, Member, appName, billPdfFrom, BillView, build, doc, image (+5 more)

### Community 59 - "Menu Service"
Cohesion: 0.12
Nodes (14): addEntry, _categories, createCategory, deleteCategory, deleteEntry, _entries, entryId, listCategories (+6 more)

### Community 60 - "App Gate"
Cohesion: 0.12
Nodes (3): error, _Failed, onRetry

### Community 61 - "Scan Service"
Cohesion: 0.12
Nodes (14): _freshOrNull, lockId, _log, _notifications, _platesCost, processScan, recentScans, reverseScan (+6 more)

### Community 62 - "Unit Field"
Cohesion: 0.13
Nodes (13): build, createState, _custom, _customSentinel, dispose, _emit, initial, initState (+5 more)

### Community 63 - "Host Setup Screen"
Cohesion: 0.14
Nodes (13): build, _busy, _confirm, createState, dispose, _error, HostSetupScreen, _HostSetupScreenState (+5 more)

### Community 64 - "Settings Screen"
Cohesion: 0.13
Nodes (4): createState, dispose, _field, _group

### Community 65 - "Messages"
Cohesion: 0.13
Nodes (9): _appError, _authError, confirmWordMatches, errorText, _firestoreError, notificationText, reversalText, scanText (+1 more)

### Community 66 - "Session Memory"
Cohesion: 0.13
Nodes (11): credentialStoreProvider, forgetEverything, forgetLogin, greeting, _log, _ref, remember, SessionMemory (+3 more)

### Community 67 - "User Service"
Cohesion: 0.13
Nodes (12): AuthService, _auth, create, delete, list, _log, _requireFreeUsername, _store (+4 more)

### Community 68 - "Labels"
Cohesion: 0.13
Nodes (14): mealLabel, mealWire, memberTypeLabel, money, number, paymentMethodLabel, paymentStatusLabel, roleLabel (+6 more)

### Community 69 - "Motion"
Cohesion: 0.17
Nodes (12): KitchenSetupScreen, _KitchenSetupScreenState, _RecoverPasswordDialog, _RecoverPasswordDialogState, _ResetConfirmDialog, _ResetConfirmDialogState, _MemberPickerSheet, _MemberPickerSheetState (+4 more)

### Community 70 - "Appearance Screen"
Cohesion: 0.13
Nodes (10): appearance, _apply, _busy, createState, enabled, enforced, _LanguageSelector, _ModeSelector (+2 more)

### Community 71 - "Nb Text Field"
Cohesion: 0.13
Nodes (12): autofocus, build, controller, errorText, formatters, hint, keyboardType, label (+4 more)

### Community 72 - "Reports Screen"
Cohesion: 0.15
Nodes (10): build, _busy, createState, _exportReport, _pickRange, _range, ReportsScreen, _ReportsScreenState (+2 more)

### Community 73 - "Nb Feedback"
Cohesion: 0.14
Nodes (13): _DayPanel, _MonthGrid, TopUpScreen, _UnitRow, _MessageOverlay, _ResultOverlay, _ReticleOverlay, NbMemberField (+5 more)

### Community 74 - "Recipes Screen"
Cohesion: 0.16
Nodes (12): allIngredients, build, dish, ingredients, _Line, lines, ok, _recipesProvider (+4 more)

### Community 75 - "Theme Preview"
Cohesion: 0.15
Nodes (9): brightness, build, enabled, id, _Miniature, onTap, selected, ThemePreviewCard (+1 more)

### Community 76 - "Ingredient Service"
Cohesion: 0.15
Nodes (11): adjustStock, _col, create, delete, _get, IngredientService, list, _log (+3 more)

### Community 77 - "Providers"
Cohesion: 0.23
Nodes (13): AppGate, build, _SignedInGate, accessProvider, backendReadyProvider, build, firebaseAppProvider, grantProvider (+5 more)

### Community 78 - "Online Accounts Screen"
Cohesion: 0.17
Nodes (12): OnlineAccount, account, _add, _AddAccountDialog, _AddAccountDialogState, _busy, _create, createState (+4 more)

### Community 79 - "Backup Test"
Cohesion: 0.15
Nodes (10): b, db, dir, file, _legacyBackup, main, manifest, member (+2 more)

### Community 80 - "Motion"
Cohesion: 0.17
Nodes (9): curve, entrance, fast, isStill, normal, page, pressScale, staggerStep (+1 more)

### Community 81 - "Notice Screen"
Cohesion: 0.18
Nodes (6): actions, body, build, icon, NoticeScreen, title

### Community 82 - "Fake Backend"
Cohesion: 0.18
Nodes (6): Role, backend, db, deviceRole, login, signInAdmin

### Community 83 - "Locale Store"
Cohesion: 0.18
Nodes (8): code, fromCode, _key, locale, nativeName, _prefs, read, write

### Community 84 - "Role"
Cohesion: 0.20
Nodes (7): canBill, canScan, canUsePurchaseSchedule, fromWire, isAdmin, scanner, wire

### Community 85 - "Refunds Screen"
Cohesion: 0.31
Nodes (8): menuCategoriesProvider, build, _CategoryField, _activeMembersProvider, build, _form, _refundsProvider, RefundsScreen

### Community 86 - "Topup History Screen"
Cohesion: 0.24
Nodes (8): backend, build, _confirmReverse, _History, _historyProvider, members, TopupHistoryTab, topups

### Community 87 - "Typography"
Cohesion: 0.20
Nodes (7): body, display, family, heading, label, onColor, scale

### Community 88 - "Setup Screens Test"
Cohesion: 0.20
Nodes (3): device, main, screens

### Community 89 - "L10N Parity Test"
Cohesion: 0.20
Nodes (5): en, keys, load, main, variables

### Community 90 - "Appearance Providers"
Cohesion: 0.39
Nodes (9): appearanceIsEnforcedProvider, deviceAppearanceProvider, effectiveAppearanceProvider, hostGreetingProvider, deviceLocaleProvider, build, TiffinApp, AppearanceScreen (+1 more)

### Community 91 - "Credential Store Test"
Cohesion: 0.22
Nodes (6): CredentialStore, backing, channel, main, signIn, store

### Community 92 - "Config"
Cohesion: 0.22
Nodes (6): _, AppConfig, appVersion, logFileBackupCount, logFileMaxBytes, notificationPollInterval

### Community 93 - "Qr Service"
Cohesion: 0.25
Nodes (4): generateCodeId, QrService, _random, renderPng

### Community 94 - "Frosted Panel"
Cohesion: 0.25
Nodes (5): build, child, FrostedPanel, sheetBackground, t

### Community 95 - "Locale Providers"
Cohesion: 0.29
Nodes (5): build, LocaleController, localeStoreProvider, AppLocaleId, LocaleStore

### Community 96 - "Access"
Cohesion: 0.25
Nodes (8): Access, ApprovedDevice, NotJoined, OnlineAccess, OnlineRefused, PendingApproval, Removed, SignedOut

### Community 97 - "Firebase Config Test"
Cohesion: 0.29
Nodes (3): googleServices, main, version

### Community 99 - "Meal Type"
Cohesion: 0.29
Nodes (4): brunch, fromWire, MealType, wire

### Community 100 - "Session Memory"
Cohesion: 0.29
Nodes (7): savedHostsProvider, sessionMemoryProvider, initState, _submit, _SavedLoginsCard, _confirmReset, _confirmSignOut

### Community 101 - "Topup Screen"
Cohesion: 0.33
Nodes (5): MembersScreen, SettingsConfigScreen, build, _ChargeTab, _ChargeTabState

### Community 102 - "Bootstrap"
Cohesion: 0.33
Nodes (4): bootstrap, configure, getInstance, sharedPreferencesProvider

### Community 104 - "Settings Screen"
Cohesion: 0.50
Nodes (4): firebaseConfigProvider, build, build, _confirmChangeProject

### Community 105 - "Providers"
Cohesion: 0.67
Nodes (4): onlineAccountsEnabledProvider, onlineAccountsProvider, build, OnlineAccountsScreen

### Community 107 - "Login Screen"
Cohesion: 0.67
Nodes (3): savedLoginsForHostProvider, build, _SavedLogins

## Knowledge Gaps
- **1425 isolated node(s):** `XCTest`, `error`, `onRetry`, `appearancePolicyProvider`, `device` (+1420 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1639 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `Feedback Widgets` to `Nb Button`, `Devices & Expenses Screens`, `Bootstrap`, `Nb Feedback`, `Setup & Appearance Screens`, `Theme Preview`, `Settings Row`, `Motion`, `Notice Screen`, `Kitchen Planning Services`, `Typography`, `Kitchen Setup UI`, `Qr Service`, `Frosted Panel`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **What connects `XCTest`, `error`, `onRetry` to the rest of the system?**
  _1425 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Backend Seam` be split into smaller, more focused modules?**
  _Cohesion score 0.0196078431372549 - nodes in this community are weakly interconnected._
- **Why does `Store` connect `Kitchen Planning Services` to `Backend Seam`, `User Service`, `Device Access Model`, `Meal Windows & Cache`, `Offline Account Auth`, `Backup & Restore`, `Menu Service`, `Firestore Store`, `Ingredient Service`, `Canteen Settings`, `Top-ups & Refunds`, `Notifications & Legacy Import`, `Firebase Config & Providers`, `Report Service`, `Member Service`, `Scan Service`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Should `Ledger Models` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Why does `_` connect `Firebase Config` to `Xlsx Writer`, `Meal Type`, `Screen Awake`, `Logging`, `Kitchen Planning Services`, `Fake Backend`, `Locale Store`, `Firebase Config & Providers`, `Theme & Motion Tests`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Should `Motion & Sync State` be split into smaller, more focused modules?**
  _Cohesion score 0.04421768707482993 - nodes in this community are weakly interconnected._