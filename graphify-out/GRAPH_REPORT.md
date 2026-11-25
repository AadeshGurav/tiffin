# Graph Report - agent-a7723947990182162  (2026-11-25)

## Corpus Check
- 188 files · ~145,988 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 42 file(s) not represented in the graph (top: .xml 11, (none) 9, .plist 4)

## Summary
- 2637 nodes · 4115 edges · 147 communities (130 shown, 17 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 25 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3bf0ac86`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- backend.dart
- ledger.dart
- _
- app_theme.dart
- access.dart
- package:flutter_riverpod/flutter_riverpod.dart
- cache_warmer.dart
- auth_service.dart
- backup_service.dart
- _
- Plan — Anytime meals (ADR 0009)
- device_setup_screen.dart
- store.dart
- ADR 0002 Kitchen setup and numeric recipe quantities
- settings_service.dart
- inventory.dart
- member_picker.dart
- Scan decision order (unknown, inactive, window, duplicate, balance)
- Store
- credential_store.dart
- member.dart
- topup_service.dart
- notification_service.dart
- providers.dart
- ledger_test.dart
- ops.dart
- recipes_screen.dart
- member_service.dart
- menu_screen.dart
- palette.dart
- settings_config_screen.dart
- settings.dart
- nb_button.dart
- scanner_screen.dart
- dart:io
- shared_widgets/motion.dart
- backup_screen.dart
- nb_picker.dart
- appearance.dart
- app_logo.dart
- rules.test.js
- oklch.dart
- AppDelegate
- logging.dart
- settings_screen.dart
- shared_project.dart
- package:flutter/material.dart
- topup_screen.dart
- menu.dart
- errors.dart
- backendProvider
- meal_window.dart
- backup_test.dart
- main.dart
- login_screen.dart
- sessionProvider
- report_service.dart
- appearance_providers.dart
- bill_view.dart
- ingredient_service.dart
- app_gate.dart
- scan_service.dart
- unit_field.dart
- host_setup_screen.dart
- welcome_screen.dart
- messages.dart
- session_memory.dart
- user_service.dart
- labels.dart
- State
- appearance_screen.dart
- nb_text_field.dart
- reports_screen.dart
- StatelessWidget
- auth_frame.dart
- theme_preview.dart
- members_screen.dart
- nb_group.dart
- online_accounts_screen.dart
- search_sort_list.dart
- theme/motion.dart
- List
- devices_screen_test.dart
- locale_store.dart
- bool get
- Decision
- topup_history_screen.dart
- String?
- package:flutter_test/flutter_test.dart
- static const
- build
- credential_store_test.dart
- _
- dart:typed_data
- DEVELOPER_GUIDE.md
- error_report.dart
- canteens.dart
- ingredients_screen.dart
- MainActivity.kt
- meal_type.dart
- menu_service.dart
- Tiffin at a glance
- canteen_book.dart
- open_backup_once.dart
- provider_buttons.dart
- theme_catalog.dart
- ADR 0001 Runtime theming and data portability
- ADR 0005 Firebase offline-first, LAN host retired
- sentinels.dart
- Developer guide
- .tiffin backup (zip + data.json) and LegacyImport
- member_entity (student/staff one data type)
- Top-ups and PDF billing (cash/UPI)
- expenses_screen.dart
- Engineering standards
- iOS launch screen assets note
- clay.dart
- clean.dart
- xlsx_writer.dart
- firestore.rules security boundary
- Theme Spec
- neobrutal.dart
- number_input.dart
- ADR 0006 — Many canteens in one shared Firebase project
- frost.dart
- ../../core/errors.dart
- ADR 0007 — Plain-language, traceable, leak-free errors
- Logging — reading what the app did
- Diagrams
- Errors — for developers and for whoever troubleshoots
- build
- _ConfigFormState
- register_android_keys.sh
- AppText
- package:cloud_firestore/cloud_firestore.dart
- resetForTest
- dart:convert
- pull_logs.sh
- Access
- l10n_parity_test.dart
- MenuScreen

## God Nodes (most connected - your core abstractions)
1. `_` - 76 edges
2. `backendProvider` - 53 edges
3. `_` - 35 edges
4. `Store` - 20 edges
5. `sessionProvider` - 17 edges
6. `Plan — Anytime meals (ADR 0009)` - 16 edges
7. `accessServiceProvider` - 14 edges
8. `canteenBookProvider` - 13 edges
9. `ADR 0001 Runtime theming and data portability` - 11 edges
10. `sessionMemoryProvider` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Order and lanes` --references--> `main()`  [INFERRED]
  docs/plans/anytime-meals.md → tool/use_firebase.py
- `Dependabot weekly pub and actions updates` --conceptually_related_to--> `pubspec.yaml dependencies (firebase, riverpod, mobile_scanner)`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `Tiffin canteen coupon system (v3)` --references--> `PRD §15 Firebase offline-first (v3)`  [EXTRACTED]
  README.md → docs/PRD.md
- `Tiffin canteen coupon system (v3)` --references--> `ADR 0005 Firebase offline-first, LAN host retired`  [EXTRACTED]
  README.md → docs/adr/0005-firebase-offline-first.md
- `firestore.rules emulator tests` --references--> `ADR 0005 Firebase offline-first, LAN host retired`  [EXTRACTED]
  tool/rules-test/README.md → docs/adr/0005-firebase-offline-first.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Schema evolution v6-v8** — docs_adr_0002_kitchen_setup_and_numeric_recipe_quantities_schema_v6, docs_adr_0003_member_category_and_per_category_menu_entries_schema_v7, docs_adr_0004_ingredient_inventory_and_alerts_schema_v8 [EXTRACTED 0.95]
- **Offline-first Firestore design** — docs_adr_0005_firebase_offline_first_write_batches, docs_adr_0005_firebase_offline_first_cache_warmer, docs_adr_0005_firebase_offline_first_duplicate_scan_id, firestore_rules [EXTRACTED 1.00]
- **CI quality gates** — github_workflows_ci_pipeline, analysis_options_lints, dart_test_tool_tag, tool_rules_test_readme_rules_tests, l10n_yaml_config [INFERRED 0.85]

## Communities (147 total, 17 thin omitted)

### Community 0 - "backend.dart"
Cohesion: 0.02
Nodes (88): addExpense, addManualPurchaseItem, addMenuEntry, adjustIngredientStock, adoptOnline, auth, backups, billing (+80 more)

### Community 1 - "ledger.dart"
Cohesion: 0.04
Nodes (48): amount, balancesAfter, breakfastUnits, brunchUnits, code, createdAt, createdBy, fromJson (+40 more)

### Community 2 - "_"
Cohesion: 0.04
Nodes (37): SyncState, MotionTokens, TiffinPalette, borderBase, borderBold, borderHair, chromeBlur, chromeOpacity (+29 more)

### Community 3 - "app_theme.dart"
Cohesion: 0.07
Nodes (23): _accented, compareNames, every, foldForSearch, haystack, indexed, matchesQuery, out (+15 more)

### Community 4 - "access.dart"
Cohesion: 0.05
Nodes (38): account, _app, approve, _auth, code, createOnlineAccount, delivered, devices (+30 more)

### Community 5 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.10
Nodes (18): build, LocaleController, localeStoreProvider, Device, ScanRecord, build, ScanLogScreen, _scansProvider (+10 more)

### Community 6 - "cache_warmer.dart"
Cohesion: 0.10
Nodes (14): CacheWarmer, hashCode, _log, online, operator, pending, _publish, start (+6 more)

### Community 7 - "auth_service.dart"
Cohesion: 0.05
Nodes (38): authenticate, _constantTimeEquals, createInitialAdmin, createSession, deleteSession, expiresAt, fromJson, hashPassword (+30 more)

### Community 8 - "backup_service.dart"
Cohesion: 0.05
Nodes (34): appVersion, BackupContents, BackupService, _batchSize, collections, createdAt, dataEntry, _decrypt (+26 more)

### Community 9 - "_"
Cohesion: 0.04
Nodes (45): _, actionLabel, build, categories, centered, color, context, copyErrorCode (+37 more)

### Community 10 - "Plan — Anytime meals (ADR 0009)"
Cohesion: 0.06
Nodes (24): Order and lanes, Plan — Anytime meals (ADR 0009), Risks, S10 — Menu planning, S11 — Report columns, S12 — Refunds with anytime units (after the ledger agent), S13 — Docs and code map, S1 — Rules: a scanner phone lowers only the one balance it names (+16 more)

### Community 11 - "device_setup_screen.dart"
Cohesion: 0.13
Nodes (17): identityProvider, setupErrorProvider, build, _busy, createState, DeviceSetupScreen, _DeviceSetupScreenState, dispose (+9 more)

### Community 12 - "store.dart"
Cohesion: 0.06
Nodes (35): batch, cached, cachedDoc, canteenDoc, canteenId, Col, commit, data (+27 more)

### Community 13 - "ADR 0002 Kitchen setup and numeric recipe quantities"
Cohesion: 0.12
Nodes (3): ADR 0002 Kitchen setup and numeric recipe quantities, ADR 0003 Member category and per-category menu entries, ADR 0004 Ingredient inventory and alerts

### Community 14 - "settings_service.dart"
Cohesion: 0.06
Nodes (32): appearanceMode, appearanceMotion, appearanceTheme, appName, availableTimezones, changedFields, defaults, DocumentRef (+24 more)

### Community 15 - "inventory.dart"
Cohesion: 0.06
Nodes (29): createdAt, date, dishName, formatQuantity, fromJson, id, ingredientId, ingredientName (+21 more)

### Community 16 - "member_picker.dart"
Cohesion: 0.06
Nodes (30): _all, build, categories, category, className, contains, _createNew, createState (+22 more)

### Community 17 - "Scan decision order (unknown, inactive, window, duplicate, balance)"
Cohesion: 0.20
Nodes (10): CacheWarmer and Store.cached, Scan doc id {member}_{day}_{meal} create-only, Writes as WriteBatch (Store.commit), FieldValue.increment, Grace allowance (via_grace), Menu planning, recipes, purchase schedule, inventory, Server-enforced one scan per member per meal per day, Scan reversal within window, Scan decision order (unknown, inactive, window, duplicate, balance) (+2 more)

### Community 18 - "Store"
Cohesion: 0.10
Nodes (19): Store, _col, create, delete, list, RecipeService, _rejectNonPositiveQuantities, _requireFreeDish (+11 more)

### Community 19 - "credential_store.dart"
Cohesion: 0.07
Nodes (27): baseUrl, forgetEverything, forgetHost, forgetLogin, fromJson, hostId, invalidateToken, _key (+19 more)

### Community 20 - "member.dart"
Cohesion: 0.06
Nodes (28): balances, breakfast, brunch, category, className, createdAt, forMeal, fromJson (+20 more)

### Community 21 - "topup_service.dart"
Cohesion: 0.11
Nodes (15): BillingService, upiPaymentUri, _billing, _col, confirmPayment, create, getById, list (+7 more)

### Community 22 - "notification_service.dart"
Cohesion: 0.07
Nodes (21): Json, collections, _convert, LegacyData, LegacyImport, read, settings, _col (+13 more)

### Community 23 - "providers.dart"
Cohesion: 0.08
Nodes (31): AppGate, build, _SignedInGate, activeCanteenProvider, accessProvider, accounts, app, backend (+23 more)

### Community 24 - "ledger_test.dart"
Cohesion: 0.10
Nodes (15): ValidationException, Backend, main, b, main, student, main, refused (+7 more)

### Community 25 - "ops.dart"
Cohesion: 0.07
Nodes (26): amount, AppNotification, category, createdAt, createdBy, date, description, ExpenseDraft (+18 more)

### Community 26 - "recipes_screen.dart"
Cohesion: 0.15
Nodes (13): Recipe, allIngredients, build, dish, ingredients, _Line, lines, ok (+5 more)

### Community 27 - "member_service.dart"
Cohesion: 0.07
Nodes (26): balanceDelta, BulkFailure, BulkResult, _cleanCategory, _col, create, createBulk, created (+18 more)

### Community 28 - "menu_screen.dart"
Cohesion: 0.10
Nodes (18): _categoriesProvider, _cell, _dateOnly, day, end, entries, entryCountByDay, _mealColor (+10 more)

### Community 29 - "palette.dart"
Cohesion: 0.08
Nodes (24): accent, accept, border, brightness, ink, inkMuted, isDark, on (+16 more)

### Community 30 - "settings_config_screen.dart"
Cohesion: 0.09
Nodes (20): SettingsSnapshot, _appName, _breakfastPrice, _brunchPrice, _busy, createState, _graceEnabled, _graceUnits (+12 more)

### Community 31 - "settings.dart"
Cohesion: 0.08
Nodes (25): appearanceMode, appearanceMotion, appearanceTheme, appName, breakfast, brunch, effectiveGrace, end (+17 more)

### Community 32 - "nb_button.dart"
Cohesion: 0.09
Nodes (20): background, build, busy, foreground, icon, intensity, label, NbButton (+12 more)

### Community 33 - "scanner_screen.dart"
Cohesion: 0.05
Nodes (36): notificationsProvider, syncStateProvider, ScanResult, build, _busy, _CameraProblem, _CameraProblemState, _clear (+28 more)

### Community 34 - "dart:io"
Cohesion: 0.14
Nodes (6): dir, logFile, main, main, render, size

### Community 35 - "shared_widgets/motion.dart"
Cohesion: 0.09
Nodes (20): _animation, build, child, _controller, createState, curve, delay, dispose (+12 more)

### Community 36 - "backup_screen.dart"
Cohesion: 0.09
Nodes (21): BackupManifest, backups, BackupScreen, _BackupScreenState, build, _busy, bytes, _confirm (+13 more)

### Community 37 - "nb_picker.dart"
Cohesion: 0.09
Nodes (22): build, child, createState, dispose, emptyHint, _filter, initState, label (+14 more)

### Community 38 - "appearance.dart"
Cohesion: 0.09
Nodes (22): appName, brightness, copyWith, defaults, enforced, fromWire, hostId, isIdentified (+14 more)

### Community 39 - "app_logo.dart"
Cohesion: 0.10
Nodes (18): AppWordmark, border, borderWidth, build, CouponPainter, _couponPath, fill, ink (+10 more)

### Community 40 - "rules.test.js"
Cohesion: 0.09
Nodes (15): ADR-0005, firebase, @firebase/rules-unit-testing, firebase-tools, description, devDependencies, firebase, @firebase/rules-unit-testing (+7 more)

### Community 41 - "oklch.dart"
Cohesion: 0.09
Nodes (21): best, bestRatio, c, channel, contrastRatio, darken, darker, _encode (+13 more)

### Community 42 - "AppDelegate"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 43 - "logging.dart"
Cohesion: 0.06
Nodes (22): _append, AppLogger, _bytesWritten, configure, _configured, defaultLevel, flush, formatRecord (+14 more)

### Community 44 - "settings_screen.dart"
Cohesion: 0.10
Nodes (11): sessionMemoryProvider, initState, _submit, _confirmReset, _confirmSignOut, createState, dispose, _field (+3 more)

### Community 45 - "shared_project.dart"
Cohesion: 0.22
Nodes (6): _android, demo, _ios, options, projectId, SharedProject

### Community 46 - "package:flutter/material.dart"
Cohesion: 0.08
Nodes (11): icon, label, onTap, _PrimaryTile, BrandSplash, build, message, build (+3 more)

### Community 47 - "topup_screen.dart"
Cohesion: 0.09
Nodes (21): PaymentMethod, _amount, build, _busy, _canSubmit, _ChargeTab, _ChargeTabState, createState (+13 more)

### Community 48 - "menu.dart"
Cohesion: 0.11
Nodes (17): category, createdAt, createdBy, date, description, fromJson, headcount, id (+9 more)

### Community 49 - "errors.dart"
Cohesion: 0.17
Nodes (12): AppException, args, AuthException, code, ConflictException, ErrorCode, ForbiddenException, InternalException (+4 more)

### Community 50 - "backendProvider"
Cohesion: 0.11
Nodes (20): backendProvider, login, resumeWithToken, AppUser, build, _categoriesProvider, _form, MenuCategoriesScreen (+12 more)

### Community 51 - "meal_window.dart"
Cohesion: 0.10
Nodes (17): _asMinutes, contains, currentMealType, dayBounds, end, HhMm, hour, isAfter (+9 more)

### Community 52 - "backup_test.dart"
Cohesion: 0.10
Nodes (13): at, main, windows, b, db, dir, file, _legacyBackup (+5 more)

### Community 53 - "main.dart"
Cohesion: 0.11
Nodes (9): crashText, details, _FriendlyErrorWidget, main, prefs, priorOnError, ref, _StartupFailed (+1 more)

### Community 54 - "login_screen.dart"
Cohesion: 0.12
Nodes (17): savedLoginsForHostProvider, build, _busy, _confirm, createState, dispose, _error, initialUsername (+9 more)

### Community 55 - "sessionProvider"
Cohesion: 0.16
Nodes (18): canteenBookProvider, accessServiceProvider, devicesProvider, logout, pendingJoinsProvider, sessionProvider, AdminDashboard, build (+10 more)

### Community 56 - "report_service.dart"
Cohesion: 0.09
Nodes (16): bootstrap, configure, getInstance, all, build, _expenses, fileName, label (+8 more)

### Community 57 - "appearance_providers.dart"
Cohesion: 0.14
Nodes (14): AppearanceController, appearancePolicyProvider, appearanceStoreProvider, build, device, _save, setMode, setMotion (+6 more)

### Community 58 - "bill_view.dart"
Cohesion: 0.12
Nodes (12): Member, appName, billPdfFrom, BillView, build, doc, image, member (+4 more)

### Community 59 - "ingredient_service.dart"
Cohesion: 0.15
Nodes (11): adjustStock, _col, create, delete, _get, IngredientService, list, _log (+3 more)

### Community 60 - "app_gate.dart"
Cohesion: 0.11
Nodes (4): error, _Failed, onRetry, stack

### Community 61 - "scan_service.dart"
Cohesion: 0.08
Nodes (22): _col, create, list, _log, RefundService, _rejectOverRefund, _settings, _store (+14 more)

### Community 62 - "unit_field.dart"
Cohesion: 0.13
Nodes (13): build, createState, _custom, _customSentinel, dispose, _emit, initial, initState (+5 more)

### Community 63 - "host_setup_screen.dart"
Cohesion: 0.14
Nodes (13): build, _busy, _confirm, createState, dispose, _error, HostSetupScreen, _HostSetupScreenState (+5 more)

### Community 64 - "welcome_screen.dart"
Cohesion: 0.10
Nodes (20): identityChangesProvider, build, _busy, canteens, _code, _create, createState, dispose (+12 more)

### Community 65 - "messages.dart"
Cohesion: 0.12
Nodes (12): _appError, _authError, confirmWordMatches, describeError, errorText, _expected, _firestoreError, _knownText (+4 more)

### Community 66 - "session_memory.dart"
Cohesion: 0.11
Nodes (13): credentialStoreProvider, forgetEverything, forgetLogin, greeting, _log, _ref, remember, savedHostsProvider (+5 more)

### Community 67 - "user_service.dart"
Cohesion: 0.13
Nodes (12): AuthService, _auth, create, delete, list, _log, _requireFreeUsername, _store (+4 more)

### Community 68 - "labels.dart"
Cohesion: 0.12
Nodes (14): mealLabel, mealWire, memberTypeLabel, money, number, paymentMethodLabel, paymentStatusLabel, roleLabel (+6 more)

### Community 69 - "State"
Cohesion: 0.17
Nodes (14): _RestoreConfirmDialog, _RestoreConfirmDialogState, _RecoverPasswordDialog, _RecoverPasswordDialogState, _MemberPickerSheet, _MemberPickerSheetState, _DelayedBuilder, _DelayedBuilderState (+6 more)

### Community 70 - "appearance_screen.dart"
Cohesion: 0.12
Nodes (10): appearance, _apply, _busy, createState, enabled, enforced, _LanguageSelector, _ModeSelector (+2 more)

### Community 71 - "nb_text_field.dart"
Cohesion: 0.13
Nodes (12): autofocus, build, controller, errorText, formatters, hint, keyboardType, label (+4 more)

### Community 72 - "reports_screen.dart"
Cohesion: 0.15
Nodes (10): build, _busy, createState, _exportReport, _pickRange, _range, ReportsScreen, _ReportsScreenState (+2 more)

### Community 73 - "StatelessWidget"
Cohesion: 0.14
Nodes (13): _DayPanel, _MonthGrid, TopUpScreen, _MessageOverlay, _ResultOverlay, _ReticleOverlay, AppLogo, FrostedPanel (+5 more)

### Community 74 - "auth_frame.dart"
Cohesion: 0.12
Nodes (15): action, AuthFrame, body, build, _CanteenBar, canteenName, error, _ErrorLine (+7 more)

### Community 75 - "theme_preview.dart"
Cohesion: 0.15
Nodes (9): brightness, build, enabled, id, _Miniature, onTap, selected, ThemePreviewCard (+1 more)

### Community 76 - "members_screen.dart"
Cohesion: 0.07
Nodes (30): menuCategoriesProvider, Refund, build, _busy, _category, _CategoryField, _className, createState (+22 more)

### Community 77 - "nb_group.dart"
Cohesion: 0.12
Nodes (15): build, child, children, danger, icon, NbGroup, NbListRow, NbRow (+7 more)

### Community 78 - "online_accounts_screen.dart"
Cohesion: 0.07
Nodes (23): OnlineAccount, build, createState, dispose, KitchenSetupScreen, _KitchenSetupScreenState, _onTab, _tabs (+15 more)

### Community 79 - "search_sort_list.dart"
Cohesion: 0.14
Nodes (11): build, compare, createState, dispose, items, label, _query, searchLabel (+3 more)

### Community 80 - "theme/motion.dart"
Cohesion: 0.17
Nodes (9): curve, entrance, fast, isStill, normal, page, pressScale, staggerStep (+1 more)

### Community 81 - "List"
Cohesion: 0.18
Nodes (6): actions, body, build, icon, NoticeScreen, title

### Community 82 - "devices_screen_test.dart"
Cohesion: 0.08
Nodes (18): Role, main, main, person, phone, _App, db, main (+10 more)

### Community 83 - "locale_store.dart"
Cohesion: 0.15
Nodes (10): AppLocaleId, code, fromCode, _key, locale, LocaleStore, nativeName, _prefs (+2 more)

### Community 84 - "bool get"
Cohesion: 0.20
Nodes (7): canBill, canScan, canUsePurchaseSchedule, fromWire, isAdmin, scanner, wire

### Community 85 - "Decision"
Cohesion: 0.14
Nodes (13): 1. A meal is identified by a string id. The three built-ins keep theirs., 2. The catalogue lives in the settings document, 3. Balances: the member map just gains keys, 4. Top-ups and refunds: built-ins stay flat, anytime units go in one map, 5. The scan: the operator picks an anytime meal on the scanner, and it stays picked, 6. Rules: a scanner phone may lower exactly one balance, the one it names, 7. Planning and categorising, 8. Reports and exports (+5 more)

### Community 86 - "topup_history_screen.dart"
Cohesion: 0.12
Nodes (13): Topup, backend, build, _confirmReverse, _History, _historyProvider, members, TopupHistoryTab (+5 more)

### Community 87 - "String?"
Cohesion: 0.20
Nodes (7): body, display, family, heading, label, onColor, scale

### Community 88 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.06
Nodes (17): main, device, main, pumpScreen, screens, app, main, app (+9 more)

### Community 89 - "static const"
Cohesion: 0.18
Nodes (5): didChangeAppLifecycleState, LifecycleLogger, _log, _channel, ScreenAwake

### Community 90 - "build"
Cohesion: 0.39
Nodes (9): appearanceIsEnforcedProvider, deviceAppearanceProvider, effectiveAppearanceProvider, hostGreetingProvider, deviceLocaleProvider, build, TiffinApp, AppearanceScreen (+1 more)

### Community 91 - "credential_store_test.dart"
Cohesion: 0.20
Nodes (6): CredentialStore, backing, channel, main, signIn, store

### Community 92 - "_"
Cohesion: 0.22
Nodes (6): _, AppConfig, appVersion, logFileBackupCount, logFileMaxBytes, notificationPollInterval

### Community 93 - "dart:typed_data"
Cohesion: 0.25
Nodes (4): generateCodeId, QrService, _random, renderPng

### Community 94 - "DEVELOPER_GUIDE.md"
Cohesion: 0.30
Nodes (6): 0008 — Feature-grouped folders; tests mirror lib/, PRD — Tiffin unit-based canteen coupon system, PRD §14 Neobrutalism visual theme, Documentation, Tiffin User Guide (v3), Tiffin canteen coupon system (v3)

### Community 95 - "error_report.dart"
Cohesion: 0.18
Nodes (9): _alphabet, chunk, _log, message, newReferenceCode, _random, ref, reportedRefs (+1 more)

### Community 96 - "canteens.dart"
Cohesion: 0.10
Nodes (16): addSignInMethod, _alphabet, _auth, CanteenService, codeLength, _db, _log, nameOf (+8 more)

### Community 97 - "ingredients_screen.dart"
Cohesion: 0.06
Nodes (33): Ingredient, PurchaseScheduleItem, _adjustStock, build, ingredientsProvider, IngredientsTab, lowAt, name (+25 more)

### Community 99 - "meal_type.dart"
Cohesion: 0.29
Nodes (4): brunch, fromWire, MealType, wire

### Community 100 - "menu_service.dart"
Cohesion: 0.13
Nodes (14): addEntry, _categories, createCategory, deleteCategory, deleteEntry, _entries, entryId, listCategories (+6 more)

### Community 101 - "Tiffin at a glance"
Cohesion: 0.20
Nodes (10): Controls, and what to know, Decisions already made, Glossary, How a day works, How it is built, Tiffin at a glance, What it is, Where it stands (+2 more)

### Community 102 - "canteen_book.dart"
Cohesion: 0.09
Nodes (20): sharedPreferencesProvider, activate, active, activeCode, build, CanteenBook, CanteenBookState, canteens (+12 more)

### Community 103 - "open_backup_once.dart"
Cohesion: 0.20
Nodes (7): startFromBackupProvider, build, child, createState, initState, OpenBackupOnce, _OpenBackupOnceState

### Community 104 - "provider_buttons.dart"
Cohesion: 0.16
Nodes (11): canteenServiceProvider, _appleEnabled, build, _busy, createState, _error, _go, _microsoftEnabled (+3 more)

### Community 105 - "theme_catalog.dart"
Cohesion: 0.20
Nodes (5): defaultTheme, fromWire, TiffinThemeId, tokens, wire

### Community 107 - "ADR 0005 Firebase offline-first, LAN host retired"
Cohesion: 0.53
Nodes (5): ADR 0005 Firebase offline-first, LAN host retired, PRD §13 LAN host architecture (superseded), PRD §15 Firebase offline-first (v3), Dependabot weekly pub and actions updates, pubspec.yaml dependencies (firebase, riverpod, mobile_scanner)

### Community 109 - "Developer guide"
Cohesion: 0.25
Nodes (8): Developer guide, Docs map, Layers (`lib/`), Rules to know before your first change, Run it, Shape of the system, Typical changes, Verify before you say done

### Community 113 - "expenses_screen.dart"
Cohesion: 0.29
Nodes (8): Expense, ProfitSummary, build, _expensesProvider, ExpensesScreen, _form, _stat, _summaryProvider

### Community 122 - "clay.dart"
Cohesion: 0.25
Nodes (6): buildClay, dark, ground, ink, _light, palette

### Community 123 - "clean.dart"
Cohesion: 0.25
Nodes (6): buildClean, dark, ground, ink, _light, palette

### Community 124 - "xlsx_writer.dart"
Cohesion: 0.12
Nodes (15): add, build, _columnName, _contentTypes, _escape, headers, name, _rootRels (+7 more)

### Community 125 - "firestore.rules security boundary"
Cohesion: 0.20
Nodes (11): analysis_options.yaml strict lints, dart_test.yaml tool tag, Approved phones, offline accounts, optional online accounts, Runtime Firebase config import (FirebaseConfig), Roles: admin, counter, scanner, firestore.rules security boundary, CI workflow (analyze-test, rules-test, build-apk, build-ios), l10n.yaml (AppText from app_en.arb) (+3 more)

### Community 126 - "Theme Spec"
Cohesion: 0.29
Nodes (6): Clay theme, Clean theme, Frost theme, Neobrutal theme, OKLCH palettes, Theme Spec

### Community 127 - "neobrutal.dart"
Cohesion: 0.29
Nodes (6): buildNeobrutal, dark, ground, ink, _light, palette

### Community 128 - "number_input.dart"
Cohesion: 0.25
Nodes (5): parseAmount, parseWholeNumber, trimmed, tryParse, value

### Community 129 - "ADR 0006 — Many canteens in one shared Firebase project"
Cohesion: 0.33
Nodes (5): ADR 0006 — Many canteens in one shared Firebase project, Consequences, Context, Decision, Rejected

### Community 130 - "frost.dart"
Cohesion: 0.29
Nodes (6): buildFrost, dark, ground, ink, _light, palette

### Community 131 - "../../core/errors.dart"
Cohesion: 0.17
Nodes (9): addManual, _col, deleteItem, generate, list, PurchaseScheduleService, _roundUp2, _store (+1 more)

### Community 132 - "ADR 0007 — Plain-language, traceable, leak-free errors"
Cohesion: 0.40
Nodes (5): ADR 0007 — Plain-language, traceable, leak-free errors, Consequences, Context, Decision, Rejected

### Community 133 - "Logging — reading what the app did"
Cohesion: 0.40
Nodes (5): Behaviour, Getting the file, Logging — reading what the app did, Reading it, What gets logged for free

### Community 134 - "Diagrams"
Cohesion: 0.50
Nodes (4): Changing one, Diagrams, Keeping them true, Why generated SVG, not GIF or Mermaid

### Community 135 - "Errors — for developers and for whoever troubleshoots"
Cohesion: 0.50
Nodes (4): Adding an error (developer), Errors — for developers and for whoever troubleshoots, Finding a failure by code (operator / IT), Where a failure surfaces

### Community 136 - "build"
Cohesion: 0.67
Nodes (4): onlineAccountsEnabledProvider, onlineAccountsProvider, build, OnlineAccountsScreen

### Community 137 - "_ConfigFormState"
Cohesion: 0.50
Nodes (4): build, _ConfigForm, _ConfigFormState, _timezonesProvider

### Community 138 - "register_android_keys.sh"
Cohesion: 0.83
Nodes (3): fingerprints(), prop(), register_android_keys.sh script

### Community 140 - "package:cloud_firestore/cloud_firestore.dart"
Cohesion: 0.25
Nodes (4): main, records, sub, text

### Community 142 - "dart:convert"
Cohesion: 0.25
Nodes (4): main, open, read, writer

### Community 144 - "Access"
Cohesion: 0.25
Nodes (8): Access, ApprovedDevice, NotJoined, OnlineAccess, OnlineRefused, PendingApproval, Removed, SignedOut

### Community 145 - "l10n_parity_test.dart"
Cohesion: 0.25
Nodes (5): en, keys, load, main, variables

### Community 146 - "MenuScreen"
Cohesion: 0.47
Nodes (5): build, _menuProvider, MenuScreen, _monthProvider, _selectedDayProvider

## Knowledge Gaps
- **1641 isolated node(s):** `XCTest`, `error`, `stack`, `onRetry`, `appearancePolicyProvider` (+1636 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1889 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `nb_button.dart`, `ingredients_screen.dart`, `../../core/errors.dart`, `State`, `package:flutter_riverpod/flutter_riverpod.dart`, `open_backup_once.dart`, `provider_buttons.dart`, `StatelessWidget`, `package:flutter/material.dart`, `theme/motion.dart`, `List`, `member.dart`, `topup_history_screen.dart`, `providers.dart`, `String?`, `credential_store_test.dart`, `app_gate.dart`, `dart:typed_data`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **What connects `XCTest`, `error`, `stack` to the rest of the system?**
  _1641 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `backend.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.019417475728155338 - nodes in this community are weakly interconnected._
- **Why does `_` connect `_` to `nb_button.dart`, `package:flutter/material.dart`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Should `ledger.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.038461538461538464 - nodes in this community are weakly interconnected._
- **Why does `Store` connect `Store` to `backend.dart`, `../../core/errors.dart`, `access.dart`, `menu_service.dart`, `cache_warmer.dart`, `auth_service.dart`, `member_service.dart`, `user_service.dart`, `backup_service.dart`, `store.dart`, `settings_service.dart`, `topup_service.dart`, `notification_service.dart`, `providers.dart`, `report_service.dart`, `ingredient_service.dart`, `scan_service.dart`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Should `_` be split into smaller, more focused modules?**
  _Cohesion score 0.04421768707482993 - nodes in this community are weakly interconnected._