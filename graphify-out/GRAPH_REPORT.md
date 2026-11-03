# Graph Report - canteen-coupon-system  (2026-11-03)

## Corpus Check
- 153 files · ~124,277 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 40 file(s) not represented in the graph (top: .xml 11, (none) 7, .plist 4)

## Summary
- 2320 nodes · 3563 edges · 131 communities (113 shown, 18 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6be9c2b8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- backend.dart
- ledger.dart
- _
- app_theme.dart
- access.dart
- ../../app/providers.dart
- cache_warmer.dart
- auth_service.dart
- backup_service.dart
- _
- members_screen.dart
- device_setup_screen.dart
- store.dart
- ADR 0003 Member category and per-category menu entries
- settings_service.dart
- inventory.dart
- member_picker.dart
- Scan decision order (unknown, inactive, window, duplicate, balance)
- ../../core/errors.dart
- credential_store.dart
- member.dart
- topup_service.dart
- notification_service.dart
- providers.dart
- theme_render_test.dart
- ops.dart
- ../../l10n/app_localizations.dart
- member_service.dart
- menu_screen.dart
- palette.dart
- settings_config_screen.dart
- settings.dart
- nb_button.dart
- scanner_screen.dart
- xlsx_writer.dart
- shared_widgets/motion.dart
- backup_screen.dart
- nb_picker.dart
- appearance.dart
- app_logo.dart
- rules.test.js
- oklch.dart
- AppDelegate
- logging.dart
- admin_dashboard.dart
- dart:io
- package:flutter/material.dart
- topup_screen.dart
- menu.dart
- errors.dart
- app_shell.dart
- ingredients_screen.dart
- ledger_test.dart
- main.dart
- login_screen.dart
- ConsumerWidget
- report_service.dart
- appearance_providers.dart
- bill_view.dart
- menu_service.dart
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
- package:flutter_riverpod/flutter_riverpod.dart
- StatelessWidget
- recipes_screen.dart
- theme_preview.dart
- backendProvider
- build
- ConsumerState
- backup_test.dart
- theme/motion.dart
- List
- fake_backend.dart
- locale_store.dart
- bool get
- refunds_screen.dart
- topup_history_screen.dart
- String?
- setup_screens_test.dart
- l10n_parity_test.dart
- build
- credential_store_test.dart
- _
- dart:typed_data
- open_backup_once.dart
- locale_providers.dart
- canteens.dart
- ingredient_quick_add.dart
- MainActivity.kt
- meal_type.dart
- purchase_schedule_service.dart
- _ChargeTabState
- canteen_book.dart
- static const
- canteenBookProvider
- theme_catalog.dart
- ADR 0001 Runtime theming and data portability
- ADR 0005 Firebase offline-first, LAN host retired
- sentinels.dart
- BillingService
- .tiffin backup (zip + data.json) and LegacyImport
- member_entity (student/staff one data type)
- Top-ups and PDF billing (cash/UPI)
- expenses_screen.dart
- Engineering standards
- iOS launch screen assets note
- clay.dart
- clean.dart
- package:flutter_test/flutter_test.dart
- CI workflow (analyze-test, rules-test, build-apk, build-ios)
- Theme Spec
- neobrutal.dart
- ADR 0002 Kitchen setup and numeric recipe quantities
- ADR 0006 — Many canteens in one shared Firebase project
- _ConfigFormState

## God Nodes (most connected - your core abstractions)
1. `_` - 58 edges
2. `backendProvider` - 55 edges
3. `_` - 35 edges
4. `Store` - 20 edges
5. `sessionProvider` - 17 edges
6. `canteenBookProvider` - 13 edges
7. `accessServiceProvider` - 13 edges
8. `sessionMemoryProvider` - 10 edges
9. `_` - 10 edges
10. `ADR 0001 Runtime theming and data portability` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Moving a v2 LAN-host canteen across` --conceptually_related_to--> `.tiffin backup (zip + data.json) and LegacyImport`  [INFERRED]
  README.md → docs/adr/0005-firebase-offline-first.md
- `Tiffin canteen coupon system (v3)` --references--> `Theme Spec`  [EXTRACTED]
  README.md → docs/THEME_SPEC.md
- `CI workflow (analyze-test, rules-test, build-apk, build-ios)` --conceptually_related_to--> `analysis_options.yaml strict lints`  [INFERRED]
  .github/workflows/ci.yml → analysis_options.yaml
- `CI workflow (analyze-test, rules-test, build-apk, build-ios)` --conceptually_related_to--> `dart_test.yaml tool tag`  [INFERRED]
  .github/workflows/ci.yml → dart_test.yaml
- `firestore.rules emulator tests` --references--> `firestore.rules security boundary`  [EXTRACTED]
  tool/rules-test/README.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Schema evolution v6-v8** — docs_adr_0002_kitchen_setup_and_numeric_recipe_quantities_schema_v6, docs_adr_0003_member_category_and_per_category_menu_entries_schema_v7, docs_adr_0004_ingredient_inventory_and_alerts_schema_v8 [EXTRACTED 0.95]
- **Offline-first Firestore design** — docs_adr_0005_firebase_offline_first_write_batches, docs_adr_0005_firebase_offline_first_cache_warmer, docs_adr_0005_firebase_offline_first_duplicate_scan_id, firestore_rules [EXTRACTED 1.00]
- **CI quality gates** — github_workflows_ci_pipeline, analysis_options_lints, dart_test_tool_tag, tool_rules_test_readme_rules_tests, l10n_yaml_config [INFERRED 0.85]

## Communities (131 total, 18 thin omitted)

### Community 0 - "backend.dart"
Cohesion: 0.02
Nodes (87): addExpense, addManualPurchaseItem, addMenuEntry, adjustIngredientStock, adoptOnline, auth, backups, billing (+79 more)

### Community 1 - "ledger.dart"
Cohesion: 0.04
Nodes (50): amount, balancesAfter, breakfastUnits, brunchUnits, code, createdAt, createdBy, fromJson (+42 more)

### Community 2 - "_"
Cohesion: 0.04
Nodes (37): SyncState, MotionTokens, TiffinPalette, borderBase, borderBold, borderHair, chromeBlur, chromeOpacity (+29 more)

### Community 3 - "app_theme.dart"
Cohesion: 0.12
Nodes (12): base, border, buildTiffinTheme, color, copyWith, motion, _NoTransitionBuilder, reduceTransparency (+4 more)

### Community 4 - "access.dart"
Cohesion: 0.05
Nodes (44): Access, account, _app, approve, ApprovedDevice, _auth, code, createOnlineAccount (+36 more)

### Community 5 - "../../app/providers.dart"
Cohesion: 0.07
Nodes (22): Device, OnlineAccount, _categoriesProvider, _form, device, email, onlineRefused, pending (+14 more)

### Community 6 - "cache_warmer.dart"
Cohesion: 0.11
Nodes (14): CacheWarmer, hashCode, _log, online, operator, pending, _publish, start (+6 more)

### Community 7 - "auth_service.dart"
Cohesion: 0.05
Nodes (37): authenticate, _constantTimeEquals, createInitialAdmin, createSession, deleteSession, expiresAt, fromJson, hashPassword (+29 more)

### Community 8 - "backup_service.dart"
Cohesion: 0.05
Nodes (34): appVersion, BackupContents, BackupService, _batchSize, collections, createdAt, dataEntry, _decrypt (+26 more)

### Community 9 - "_"
Cohesion: 0.06
Nodes (35): _, actionLabel, build, categories, duration, empty, _emptyCheck, EmptyQuips (+27 more)

### Community 10 - "members_screen.dart"
Cohesion: 0.10
Nodes (20): _busy, _category, _className, createState, _delete, existing, _grace, _isEdit (+12 more)

### Community 11 - "device_setup_screen.dart"
Cohesion: 0.14
Nodes (12): _busy, createState, dispose, _email, _error, _join, _name, _online (+4 more)

### Community 12 - "store.dart"
Cohesion: 0.05
Nodes (36): batch, cached, cachedDoc, canteenDoc, canteenId, Col, commit, data (+28 more)

### Community 14 - "settings_service.dart"
Cohesion: 0.06
Nodes (31): appearanceMode, appearanceMotion, appearanceTheme, appName, availableTimezones, changedFields, defaults, enforceAppearance (+23 more)

### Community 15 - "inventory.dart"
Cohesion: 0.06
Nodes (31): createdAt, date, dishName, formatQuantity, fromJson, id, ingredientId, ingredientName (+23 more)

### Community 16 - "member_picker.dart"
Cohesion: 0.06
Nodes (30): _all, build, categories, category, className, contains, _createNew, createState (+22 more)

### Community 17 - "Scan decision order (unknown, inactive, window, duplicate, balance)"
Cohesion: 0.13
Nodes (16): Approved phones, offline accounts, optional online accounts, CacheWarmer and Store.cached, Scan doc id {member}_{day}_{meal} create-only, Runtime Firebase config import (FirebaseConfig), Writes as WriteBatch (Store.commit), FieldValue.increment, Grace allowance (via_grace), Menu planning, recipes, purchase schedule, inventory, Roles: admin, counter, scanner (+8 more)

### Community 18 - "../../core/errors.dart"
Cohesion: 0.07
Nodes (29): Store, add, _col, ExpenseService, list, _log, _store, summary (+21 more)

### Community 19 - "credential_store.dart"
Cohesion: 0.07
Nodes (27): baseUrl, forgetEverything, forgetHost, forgetLogin, fromJson, hostId, invalidateToken, _key (+19 more)

### Community 20 - "member.dart"
Cohesion: 0.07
Nodes (27): balances, breakfast, brunch, category, className, createdAt, forMeal, fromJson (+19 more)

### Community 21 - "topup_service.dart"
Cohesion: 0.08
Nodes (22): _col, create, list, _log, RefundService, _rejectOverRefund, _settings, _store (+14 more)

### Community 22 - "notification_service.dart"
Cohesion: 0.12
Nodes (14): _col, dismiss, generateDue, _headcountOverrun, listFor, _lowStock, NotificationService, _prepReminders (+6 more)

### Community 23 - "providers.dart"
Cohesion: 0.09
Nodes (18): app, backend, cacheWarmerProvider, canteen, db, _emulatorHost, Grant, onlineAccountsEnabledProvider (+10 more)

### Community 24 - "theme_render_test.dart"
Cohesion: 0.09
Nodes (11): main, render, size, main, resolve, bodyMin, expectContrast, main (+3 more)

### Community 25 - "ops.dart"
Cohesion: 0.07
Nodes (27): amount, AppNotification, AppUser, category, createdAt, createdBy, date, description (+19 more)

### Community 26 - "../../l10n/app_localizations.dart"
Cohesion: 0.12
Nodes (12): build, createState, dispose, _onTab, _tabs, build, _dateRow, _explainEmptyGenerate (+4 more)

### Community 27 - "member_service.dart"
Cohesion: 0.07
Nodes (26): balanceDelta, BulkFailure, BulkResult, _cleanCategory, _col, create, createBulk, created (+18 more)

### Community 28 - "menu_screen.dart"
Cohesion: 0.09
Nodes (23): build, _categoriesProvider, _cell, _dateOnly, day, end, entries, entryCountByDay (+15 more)

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
Cohesion: 0.09
Nodes (20): ScanResult, _busy, _clear, color, _controller, createState, dispose, _errorMessage (+12 more)

### Community 34 - "xlsx_writer.dart"
Cohesion: 0.12
Nodes (15): add, build, _columnName, _contentTypes, _escape, headers, name, _rootRels (+7 more)

### Community 35 - "shared_widgets/motion.dart"
Cohesion: 0.09
Nodes (20): _animation, build, child, _controller, createState, curve, delay, dispose (+12 more)

### Community 36 - "backup_screen.dart"
Cohesion: 0.10
Nodes (19): BackupManifest, backups, build, _busy, bytes, _confirm, count, createState (+11 more)

### Community 37 - "nb_picker.dart"
Cohesion: 0.10
Nodes (20): build, child, createState, dispose, emptyHint, _filter, initState, label (+12 more)

### Community 38 - "appearance.dart"
Cohesion: 0.09
Nodes (22): appName, brightness, copyWith, defaults, enforced, fromWire, hostId, isIdentified (+14 more)

### Community 39 - "app_logo.dart"
Cohesion: 0.09
Nodes (19): AppLogo, AppWordmark, border, borderWidth, build, CouponPainter, _couponPath, fill (+11 more)

### Community 40 - "rules.test.js"
Cohesion: 0.09
Nodes (15): ADR-0005, firebase, @firebase/rules-unit-testing, firebase-tools, description, devDependencies, firebase, @firebase/rules-unit-testing (+7 more)

### Community 41 - "oklch.dart"
Cohesion: 0.05
Nodes (38): _asMinutes, contains, currentMealType, dayBounds, end, HhMm, hour, isAfter (+30 more)

### Community 42 - "AppDelegate"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 43 - "logging.dart"
Cohesion: 0.10
Nodes (11): AppLogger, configure, _configured, dispose, _fileSink, _format, log, _logFile (+3 more)

### Community 44 - "admin_dashboard.dart"
Cohesion: 0.14
Nodes (4): _Dest, icon, label, tone

### Community 45 - "dart:io"
Cohesion: 0.20
Nodes (6): _android, demo, _ios, options, projectId, SharedProject

### Community 46 - "package:flutter/material.dart"
Cohesion: 0.11
Nodes (14): BrandSplash, build, message, build, child, FrostedPanel, sheetBackground, t (+6 more)

### Community 47 - "topup_screen.dart"
Cohesion: 0.11
Nodes (15): PaymentMethod, _amount, _busy, _canSubmit, createState, label, _lunch, _member (+7 more)

### Community 48 - "menu.dart"
Cohesion: 0.11
Nodes (17): category, createdAt, createdBy, date, description, fromJson, headcount, id (+9 more)

### Community 49 - "errors.dart"
Cohesion: 0.14
Nodes (13): AppException, args, AuthException, code, ConflictException, ErrorCode, ForbiddenException, InternalException (+5 more)

### Community 50 - "app_shell.dart"
Cohesion: 0.12
Nodes (13): notificationsProvider, syncStateProvider, build, SettingsScreen, actions, build, NbAppBar, _NotificationBell (+5 more)

### Community 51 - "ingredients_screen.dart"
Cohesion: 0.12
Nodes (17): _adjustStock, build, ingredientsProvider, IngredientsTab, lowAt, name, _num, ok (+9 more)

### Community 52 - "ledger_test.dart"
Cohesion: 0.12
Nodes (7): Backend, b, main, student, at, main, windows

### Community 53 - "main.dart"
Cohesion: 0.12
Nodes (8): crash, crashText, details, _FriendlyErrorWidget, main, prefs, priorOnError, text

### Community 54 - "login_screen.dart"
Cohesion: 0.05
Nodes (31): savedLoginsForHostProvider, sessionMemoryProvider, build, _busy, _confirm, createState, dispose, _error (+23 more)

### Community 55 - "ConsumerWidget"
Cohesion: 0.21
Nodes (13): accessServiceProvider, devicesProvider, logout, sessionProvider, AdminDashboard, build, _MemberTile, build (+5 more)

### Community 56 - "report_service.dart"
Cohesion: 0.10
Nodes (15): bootstrap, configure, getInstance, all, build, _expenses, fileName, label (+7 more)

### Community 57 - "appearance_providers.dart"
Cohesion: 0.14
Nodes (14): AppearanceController, appearancePolicyProvider, appearanceStoreProvider, build, device, _save, setMode, setMotion (+6 more)

### Community 58 - "bill_view.dart"
Cohesion: 0.12
Nodes (13): Topup, Member, appName, billPdfFrom, BillView, build, doc, image (+5 more)

### Community 59 - "menu_service.dart"
Cohesion: 0.12
Nodes (14): addEntry, _categories, createCategory, deleteCategory, deleteEntry, _entries, entryId, listCategories (+6 more)

### Community 60 - "app_gate.dart"
Cohesion: 0.12
Nodes (3): error, _Failed, onRetry

### Community 61 - "scan_service.dart"
Cohesion: 0.08
Nodes (21): Json, collections, _convert, LegacyData, LegacyImport, read, settings, _freshOrNull (+13 more)

### Community 62 - "unit_field.dart"
Cohesion: 0.14
Nodes (13): build, createState, _custom, _customSentinel, dispose, _emit, initial, initState (+5 more)

### Community 63 - "host_setup_screen.dart"
Cohesion: 0.14
Nodes (11): build, _busy, _confirm, createState, dispose, _error, _password, _revealed (+3 more)

### Community 64 - "welcome_screen.dart"
Cohesion: 0.08
Nodes (21): _appleEnabled, build, _busy, createState, _error, _busy, canteens, _code (+13 more)

### Community 65 - "messages.dart"
Cohesion: 0.14
Nodes (9): _appError, _authError, confirmWordMatches, errorText, _firestoreError, notificationText, reversalText, scanText (+1 more)

### Community 66 - "session_memory.dart"
Cohesion: 0.12
Nodes (13): credentialStoreProvider, forgetEverything, forgetLogin, greeting, _log, _ref, remember, savedHostsProvider (+5 more)

### Community 67 - "user_service.dart"
Cohesion: 0.13
Nodes (12): AuthService, _auth, create, delete, list, _log, _requireFreeUsername, _store (+4 more)

### Community 68 - "labels.dart"
Cohesion: 0.11
Nodes (16): AppTextLabels, mealLabel, mealWire, memberTypeLabel, money, number, paymentMethodLabel, paymentStatusLabel (+8 more)

### Community 69 - "State"
Cohesion: 0.17
Nodes (12): _RestoreConfirmDialog, _RestoreConfirmDialogState, KitchenSetupScreen, _KitchenSetupScreenState, _MemberPickerSheet, _MemberPickerSheetState, _DelayedBuilder, _DelayedBuilderState (+4 more)

### Community 70 - "appearance_screen.dart"
Cohesion: 0.13
Nodes (10): appearance, _apply, _busy, createState, enabled, enforced, _LanguageSelector, _ModeSelector (+2 more)

### Community 71 - "nb_text_field.dart"
Cohesion: 0.13
Nodes (12): autofocus, build, controller, errorText, formatters, hint, keyboardType, label (+4 more)

### Community 72 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.12
Nodes (9): build, _busy, createState, _exportReport, _pickRange, _range, _sections, _share (+1 more)

### Community 73 - "StatelessWidget"
Cohesion: 0.15
Nodes (12): _DayPanel, _MonthGrid, TopUpScreen, _UnitRow, _MessageOverlay, _ResultOverlay, _ReticleOverlay, NbMemberField (+4 more)

### Community 74 - "recipes_screen.dart"
Cohesion: 0.18
Nodes (12): allIngredients, build, dish, ingredients, _Line, lines, ok, _recipesProvider (+4 more)

### Community 75 - "theme_preview.dart"
Cohesion: 0.17
Nodes (9): brightness, build, enabled, id, _Miniature, onTap, selected, ThemePreviewCard (+1 more)

### Community 76 - "backendProvider"
Cohesion: 0.13
Nodes (18): backendProvider, login, resumeWithToken, _restore, _credit, _showQr, build, MenuCategoriesScreen (+10 more)

### Community 77 - "build"
Cohesion: 0.26
Nodes (12): AppGate, build, _SignedInGate, activeCanteenProvider, accessProvider, backendReadyProvider, build, firebaseAppProvider (+4 more)

### Community 78 - "ConsumerState"
Cohesion: 0.17
Nodes (14): BackupScreen, _BackupScreenState, _MemberForm, _MemberFormState, ReportsScreen, _ReportsScreenState, HostSetupScreen, _HostSetupScreenState (+6 more)

### Community 79 - "backup_test.dart"
Cohesion: 0.15
Nodes (10): b, db, dir, file, _legacyBackup, main, manifest, member (+2 more)

### Community 80 - "theme/motion.dart"
Cohesion: 0.17
Nodes (9): curve, entrance, fast, isStill, normal, page, pressScale, staggerStep (+1 more)

### Community 81 - "List"
Cohesion: 0.11
Nodes (13): actions, body, build, icon, NoticeScreen, title, build, danger (+5 more)

### Community 82 - "fake_backend.dart"
Cohesion: 0.20
Nodes (6): Role, backend, db, deviceRole, login, signInAdmin

### Community 83 - "locale_store.dart"
Cohesion: 0.17
Nodes (8): code, fromCode, _key, locale, nativeName, _prefs, read, write

### Community 84 - "bool get"
Cohesion: 0.20
Nodes (7): canBill, canScan, canUsePurchaseSchedule, fromWire, isAdmin, scanner, wire

### Community 85 - "refunds_screen.dart"
Cohesion: 0.48
Nodes (5): _activeMembersProvider, build, _form, _refundsProvider, RefundsScreen

### Community 86 - "topup_history_screen.dart"
Cohesion: 0.22
Nodes (8): backend, build, _confirmReverse, _History, _historyProvider, members, TopupHistoryTab, topups

### Community 87 - "String?"
Cohesion: 0.20
Nodes (7): body, display, family, heading, label, onColor, scale

### Community 88 - "setup_screens_test.dart"
Cohesion: 0.20
Nodes (3): device, main, screens

### Community 89 - "l10n_parity_test.dart"
Cohesion: 0.18
Nodes (5): en, keys, load, main, variables

### Community 90 - "build"
Cohesion: 0.39
Nodes (9): appearanceIsEnforcedProvider, deviceAppearanceProvider, effectiveAppearanceProvider, hostGreetingProvider, deviceLocaleProvider, build, TiffinApp, AppearanceScreen (+1 more)

### Community 91 - "credential_store_test.dart"
Cohesion: 0.22
Nodes (6): CredentialStore, backing, channel, main, signIn, store

### Community 92 - "_"
Cohesion: 0.22
Nodes (6): _, AppConfig, appVersion, logFileBackupCount, logFileMaxBytes, notificationPollInterval

### Community 93 - "dart:typed_data"
Cohesion: 0.25
Nodes (4): generateCodeId, QrService, _random, renderPng

### Community 94 - "open_backup_once.dart"
Cohesion: 0.20
Nodes (7): startFromBackupProvider, build, child, createState, initState, OpenBackupOnce, _OpenBackupOnceState

### Community 95 - "locale_providers.dart"
Cohesion: 0.29
Nodes (5): build, LocaleController, localeStoreProvider, AppLocaleId, LocaleStore

### Community 96 - "canteens.dart"
Cohesion: 0.10
Nodes (16): addSignInMethod, _alphabet, _auth, CanteenService, codeLength, _db, _log, nameOf (+8 more)

### Community 97 - "ingredient_quick_add.dart"
Cohesion: 0.15
Nodes (8): Ingredient, done, made, name, ok, showQuickAddIngredient, t, unit

### Community 99 - "meal_type.dart"
Cohesion: 0.29
Nodes (4): brunch, fromWire, MealType, wire

### Community 100 - "purchase_schedule_service.dart"
Cohesion: 0.17
Nodes (9): addManual, _col, deleteItem, generate, list, PurchaseScheduleService, _roundUp2, _store (+1 more)

### Community 101 - "_ChargeTabState"
Cohesion: 0.22
Nodes (8): menuCategoriesProvider, build, _CategoryField, MembersScreen, SettingsConfigScreen, build, _ChargeTab, _ChargeTabState

### Community 102 - "canteen_book.dart"
Cohesion: 0.09
Nodes (20): sharedPreferencesProvider, activate, active, activeCode, build, CanteenBook, CanteenBookState, canteens (+12 more)

### Community 104 - "canteenBookProvider"
Cohesion: 0.15
Nodes (17): canteenBookProvider, canteenServiceProvider, identityChangesProvider, identityProvider, build, DeviceSetupScreen, _DeviceSetupScreenState, _go (+9 more)

### Community 105 - "theme_catalog.dart"
Cohesion: 0.20
Nodes (5): defaultTheme, fromWire, TiffinThemeId, tokens, wire

### Community 107 - "ADR 0005 Firebase offline-first, LAN host retired"
Cohesion: 0.33
Nodes (8): ADR 0005 Firebase offline-first, LAN host retired, PRD — Tiffin unit-based canteen coupon system, PRD §13 LAN host architecture (superseded), PRD §14 Neobrutalism visual theme, PRD §15 Firebase offline-first (v3), Dependabot weekly pub and actions updates, pubspec.yaml dependencies (firebase, riverpod, mobile_scanner), Tiffin canteen coupon system (v3)

### Community 113 - "expenses_screen.dart"
Cohesion: 0.33
Nodes (7): ProfitSummary, build, _expensesProvider, ExpensesScreen, _form, _stat, _summaryProvider

### Community 122 - "clay.dart"
Cohesion: 0.25
Nodes (6): buildClay, dark, ground, ink, _light, palette

### Community 123 - "clean.dart"
Cohesion: 0.25
Nodes (6): buildClean, dark, ground, ink, _light, palette

### Community 124 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.25
Nodes (4): main, open, read, writer

### Community 125 - "CI workflow (analyze-test, rules-test, build-apk, build-ios)"
Cohesion: 0.38
Nodes (6): analysis_options.yaml strict lints, dart_test.yaml tool tag, CI workflow (analyze-test, rules-test, build-apk, build-ios), l10n.yaml (AppText from app_en.arb), Makefile setup/run/test commands, firestore.rules emulator tests

### Community 126 - "Theme Spec"
Cohesion: 0.29
Nodes (6): Clay theme, Clean theme, Frost theme, Neobrutal theme, OKLCH palettes, Theme Spec

### Community 127 - "neobrutal.dart"
Cohesion: 0.29
Nodes (6): buildNeobrutal, dark, ground, ink, _light, palette

### Community 129 - "ADR 0006 — Many canteens in one shared Firebase project"
Cohesion: 0.33
Nodes (5): ADR 0006 — Many canteens in one shared Firebase project, Consequences, Context, Decision, Rejected

### Community 130 - "_ConfigFormState"
Cohesion: 0.50
Nodes (4): build, _ConfigForm, _ConfigFormState, _timezonesProvider

## Knowledge Gaps
- **1463 isolated node(s):** `XCTest`, `error`, `onRetry`, `appearancePolicyProvider`, `device` (+1458 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1682 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `welcome_screen.dart`, `nb_button.dart`, `ingredient_quick_add.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `StatelessWidget`, `package:flutter/material.dart`, `theme/motion.dart`, `List`, `../../core/errors.dart`, `String?`, `report_service.dart`, `../../l10n/app_localizations.dart`, `dart:typed_data`, `open_backup_once.dart`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **What connects `XCTest`, `error`, `onRetry` to the rest of the system?**
  _1463 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `backend.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0196078431372549 - nodes in this community are weakly interconnected._
- **Why does `Store` connect `../../core/errors.dart` to `backend.dart`, `user_service.dart`, `access.dart`, `purchase_schedule_service.dart`, `cache_warmer.dart`, `auth_service.dart`, `backup_service.dart`, `menu_service.dart`, `store.dart`, `settings_service.dart`, `topup_service.dart`, `notification_service.dart`, `providers.dart`, `report_service.dart`, `member_service.dart`, `scan_service.dart`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Should `ledger.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Why does `_` connect `_` to `nb_button.dart`, `package:flutter/material.dart`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Should `_` be split into smaller, more focused modules?**
  _Cohesion score 0.04421768707482993 - nodes in this community are weakly interconnected._