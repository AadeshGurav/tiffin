# Graph Report - canteen-coupon-system  (2026-11-18)

## Corpus Check
- 175 files · ~138,423 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 41 file(s) not represented in the graph (top: .xml 11, (none) 8, .plist 4)

## Summary
- 2528 nodes · 3894 edges · 144 communities (124 shown, 20 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0d017c23`
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
- use_firebase.py
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
- recipes_screen.dart
- member_service.dart
- menu_screen.dart
- palette.dart
- settings_config_screen.dart
- settings.dart
- nb_button.dart
- scanner_screen.dart
- package:flutter_test/flutter_test.dart
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
- static const
- ../theme/tokens.dart
- topup_screen.dart
- menu.dart
- errors.dart
- ../../l10n/app_localizations.dart
- meal_window.dart
- backup_test.dart
- main.dart
- login_screen.dart
- ConsumerWidget
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
- backendProvider
- nb_group.dart
- ConsumerState
- shape.dart
- theme/motion.dart
- List
- fake_backend.dart
- locale_store.dart
- bool get
- refunds_screen.dart
- topup_history_screen.dart
- typography.dart
- setup_screens_test.dart
- l10n_parity_test.dart
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
- @immutable
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
- package:flutter/material.dart
- xlsx_writer.dart
- firestore.rules security boundary
- Theme Spec
- neobrutal.dart
- number_input.dart
- ADR 0006 — Many canteens in one shared Firebase project
- frost.dart
- String?
- ADR 0007 — Plain-language, traceable, leak-free errors
- Logging — reading what the app did
- Diagrams
- Errors — for developers and for whoever troubleshoots
- build
- _ConfigFormState
- register_android_keys.sh
- AppText
- BillingService
- resetForTest
- TiffinTokensContext
- pull_logs.sh

## God Nodes (most connected - your core abstractions)
1. `_` - 76 edges
2. `backendProvider` - 55 edges
3. `_` - 35 edges
4. `Store` - 20 edges
5. `sessionProvider` - 17 edges
6. `canteenBookProvider` - 13 edges
7. `accessServiceProvider` - 13 edges
8. `ADR 0001 Runtime theming and data portability` - 11 edges
9. `sessionMemoryProvider` - 10 edges
10. `_` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Dependabot weekly pub and actions updates` --conceptually_related_to--> `pubspec.yaml dependencies (firebase, riverpod, mobile_scanner)`  [INFERRED]
  .github/dependabot.yml → pubspec.yaml
- `Tiffin canteen coupon system (v3)` --references--> `PRD §15 Firebase offline-first (v3)`  [EXTRACTED]
  README.md → docs/PRD.md
- `Tiffin canteen coupon system (v3)` --references--> `ADR 0005 Firebase offline-first, LAN host retired`  [EXTRACTED]
  README.md → docs/adr/0005-firebase-offline-first.md
- `firestore.rules emulator tests` --references--> `ADR 0005 Firebase offline-first, LAN host retired`  [EXTRACTED]
  tool/rules-test/README.md → docs/adr/0005-firebase-offline-first.md
- `Tiffin canteen coupon system (v3)` --references--> `Theme Spec`  [EXTRACTED]
  README.md → docs/THEME_SPEC.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Schema evolution v6-v8** — docs_adr_0002_kitchen_setup_and_numeric_recipe_quantities_schema_v6, docs_adr_0003_member_category_and_per_category_menu_entries_schema_v7, docs_adr_0004_ingredient_inventory_and_alerts_schema_v8 [EXTRACTED 0.95]
- **Offline-first Firestore design** — docs_adr_0005_firebase_offline_first_write_batches, docs_adr_0005_firebase_offline_first_cache_warmer, docs_adr_0005_firebase_offline_first_duplicate_scan_id, firestore_rules [EXTRACTED 1.00]
- **CI quality gates** — github_workflows_ci_pipeline, analysis_options_lints, dart_test_tool_tag, tool_rules_test_readme_rules_tests, l10n_yaml_config [INFERRED 0.85]

## Communities (144 total, 20 thin omitted)

### Community 0 - "backend.dart"
Cohesion: 0.02
Nodes (88): addExpense, addManualPurchaseItem, addMenuEntry, adjustIngredientStock, adoptOnline, auth, backups, billing (+80 more)

### Community 1 - "ledger.dart"
Cohesion: 0.04
Nodes (50): amount, balancesAfter, breakfastUnits, brunchUnits, code, createdAt, createdBy, fromJson (+42 more)

### Community 2 - "_"
Cohesion: 0.08
Nodes (19): _, borderWidth, color, copyWith, full, lerp, _lerpPalette, lg (+11 more)

### Community 3 - "app_theme.dart"
Cohesion: 0.12
Nodes (12): base, border, buildTiffinTheme, color, copyWith, motion, _NoTransitionBuilder, reduceTransparency (+4 more)

### Community 4 - "access.dart"
Cohesion: 0.05
Nodes (45): Access, account, _app, approve, ApprovedDevice, _auth, code, createOnlineAccount (+37 more)

### Community 5 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (30): Device, OnlineAccount, _categoriesProvider, _form, build, _form, _usersProvider, UsersScreen (+22 more)

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

### Community 10 - "use_firebase.py"
Cohesion: 0.10
Nodes (8): route(), Svg, current(), die(), main(), options(), read_android(), read_ios()

### Community 11 - "device_setup_screen.dart"
Cohesion: 0.12
Nodes (16): identityProvider, build, _busy, createState, DeviceSetupScreen, _DeviceSetupScreenState, dispose, _email (+8 more)

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
Cohesion: 0.20
Nodes (10): CacheWarmer and Store.cached, Scan doc id {member}_{day}_{meal} create-only, Writes as WriteBatch (Store.commit), FieldValue.increment, Grace allowance (via_grace), Menu planning, recipes, purchase schedule, inventory, Server-enforced one scan per member per meal per day, Scan reversal within window, Scan decision order (unknown, inactive, window, duplicate, balance) (+2 more)

### Community 18 - "../../core/errors.dart"
Cohesion: 0.07
Nodes (27): Store, addManual, _col, deleteItem, generate, list, PurchaseScheduleService, _roundUp2 (+19 more)

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
Nodes (13): _col, dismiss, generateDue, _headcountOverrun, listFor, _lowStock, _prepReminders, _purchaseReminders (+5 more)

### Community 23 - "providers.dart"
Cohesion: 0.09
Nodes (27): AppGate, build, _SignedInGate, activeCanteenProvider, accessProvider, app, backend, backendReadyProvider (+19 more)

### Community 24 - "theme_render_test.dart"
Cohesion: 0.10
Nodes (9): main, render, size, bodyMin, expectContrast, main, uiMin, gallery (+1 more)

### Community 25 - "ops.dart"
Cohesion: 0.07
Nodes (27): amount, AppNotification, AppUser, category, createdAt, createdBy, date, description (+19 more)

### Community 26 - "recipes_screen.dart"
Cohesion: 0.16
Nodes (12): allIngredients, build, dish, ingredients, _Line, lines, ok, _recipesProvider (+4 more)

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
Cohesion: 0.08
Nodes (24): ScanResult, _busy, _CameraProblem, _CameraProblemState, _clear, color, _controller, createState (+16 more)

### Community 34 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.11
Nodes (8): main, records, sub, text, dir, logFile, main, main

### Community 35 - "shared_widgets/motion.dart"
Cohesion: 0.08
Nodes (22): _animation, build, child, _controller, createState, curve, delay, dispose (+14 more)

### Community 36 - "backup_screen.dart"
Cohesion: 0.09
Nodes (22): BackupManifest, backups, BackupScreen, _BackupScreenState, build, _busy, bytes, _confirm (+14 more)

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
Cohesion: 0.09
Nodes (21): best, bestRatio, c, channel, contrastRatio, darken, darker, _encode (+13 more)

### Community 42 - "AppDelegate"
Cohesion: 0.11
Nodes (6): Flutter, AppDelegate, SceneDelegate, RunnerTests, UIKit, XCTest

### Community 43 - "logging.dart"
Cohesion: 0.06
Nodes (22): _append, AppLogger, _bytesWritten, configure, _configured, defaultLevel, flush, formatRecord (+14 more)

### Community 44 - "settings_screen.dart"
Cohesion: 0.11
Nodes (9): sessionMemoryProvider, initState, _submit, _confirmReset, _confirmSignOut, createState, dispose, _field (+1 more)

### Community 45 - "static const"
Cohesion: 0.15
Nodes (8): _android, demo, _ios, options, projectId, SharedProject, _channel, ScreenAwake

### Community 46 - "../theme/tokens.dart"
Cohesion: 0.09
Nodes (9): icon, label, onTap, _PrimaryTile, build, child, FrostedPanel, sheetBackground (+1 more)

### Community 47 - "topup_screen.dart"
Cohesion: 0.09
Nodes (21): PaymentMethod, MembersScreen, _amount, build, _busy, _canSubmit, _ChargeTab, _ChargeTabState (+13 more)

### Community 48 - "menu.dart"
Cohesion: 0.11
Nodes (17): category, createdAt, createdBy, date, description, fromJson, headcount, id (+9 more)

### Community 49 - "errors.dart"
Cohesion: 0.12
Nodes (15): AppException, args, AuthException, code, ConflictException, ErrorCode, ForbiddenException, InternalException (+7 more)

### Community 50 - "../../l10n/app_localizations.dart"
Cohesion: 0.12
Nodes (9): box, path, shareLogFile, text, actions, _open, preferredSize, showSettingsButton (+1 more)

### Community 51 - "meal_window.dart"
Cohesion: 0.10
Nodes (17): _asMinutes, contains, currentMealType, dayBounds, end, HhMm, hour, isAfter (+9 more)

### Community 52 - "backup_test.dart"
Cohesion: 0.07
Nodes (17): Backend, at, main, windows, b, db, dir, file (+9 more)

### Community 53 - "main.dart"
Cohesion: 0.12
Nodes (9): crashText, details, _FriendlyErrorWidget, main, prefs, priorOnError, ref, _StartupFailed (+1 more)

### Community 54 - "login_screen.dart"
Cohesion: 0.12
Nodes (17): savedLoginsForHostProvider, build, _busy, _confirm, createState, dispose, _error, initialUsername (+9 more)

### Community 55 - "ConsumerWidget"
Cohesion: 0.12
Nodes (25): canteenBookProvider, accessServiceProvider, devicesProvider, logout, notificationsProvider, sessionProvider, syncStateProvider, AdminDashboard (+17 more)

### Community 56 - "report_service.dart"
Cohesion: 0.10
Nodes (15): bootstrap, configure, getInstance, all, build, _expenses, fileName, label (+7 more)

### Community 57 - "appearance_providers.dart"
Cohesion: 0.14
Nodes (14): AppearanceController, appearancePolicyProvider, appearanceStoreProvider, build, device, _save, setMode, setMotion (+6 more)

### Community 58 - "bill_view.dart"
Cohesion: 0.12
Nodes (13): Topup, Member, appName, billPdfFrom, BillView, build, doc, image (+5 more)

### Community 59 - "ingredient_service.dart"
Cohesion: 0.14
Nodes (11): adjustStock, _col, create, delete, _get, IngredientService, list, _log (+3 more)

### Community 60 - "app_gate.dart"
Cohesion: 0.11
Nodes (4): error, _Failed, onRetry, stack

### Community 61 - "scan_service.dart"
Cohesion: 0.08
Nodes (22): Json, _freshOrNull, lockId, _log, _notifications, _platesCost, processScan, recentScans (+14 more)

### Community 62 - "unit_field.dart"
Cohesion: 0.13
Nodes (13): build, createState, _custom, _customSentinel, dispose, _emit, initial, initState (+5 more)

### Community 63 - "host_setup_screen.dart"
Cohesion: 0.13
Nodes (13): build, _busy, _confirm, createState, dispose, _error, HostSetupScreen, _HostSetupScreenState (+5 more)

### Community 64 - "welcome_screen.dart"
Cohesion: 0.10
Nodes (20): identityChangesProvider, build, _busy, canteens, _code, _create, createState, dispose (+12 more)

### Community 65 - "messages.dart"
Cohesion: 0.12
Nodes (12): _appError, _authError, confirmWordMatches, describeError, errorText, _expected, _firestoreError, _knownText (+4 more)

### Community 66 - "session_memory.dart"
Cohesion: 0.12
Nodes (13): credentialStoreProvider, forgetEverything, forgetLogin, greeting, _log, _ref, remember, savedHostsProvider (+5 more)

### Community 67 - "user_service.dart"
Cohesion: 0.12
Nodes (12): AuthService, _auth, create, delete, list, _log, _requireFreeUsername, _store (+4 more)

### Community 68 - "labels.dart"
Cohesion: 0.12
Nodes (14): mealLabel, mealWire, memberTypeLabel, money, number, paymentMethodLabel, paymentStatusLabel, roleLabel (+6 more)

### Community 69 - "State"
Cohesion: 0.16
Nodes (14): _RestoreConfirmDialog, _RestoreConfirmDialogState, _RecoverPasswordDialog, _RecoverPasswordDialogState, _ResetConfirmDialog, _ResetConfirmDialogState, _MemberPickerSheet, _MemberPickerSheetState (+6 more)

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
Cohesion: 0.15
Nodes (12): _DayPanel, _MonthGrid, TopUpScreen, _UnitRow, _MessageOverlay, _ResultOverlay, _ReticleOverlay, NbMemberField (+4 more)

### Community 74 - "auth_frame.dart"
Cohesion: 0.12
Nodes (15): action, AuthFrame, body, build, _CanteenBar, canteenName, error, _ErrorLine (+7 more)

### Community 75 - "theme_preview.dart"
Cohesion: 0.15
Nodes (9): brightness, build, enabled, id, _Miniature, onTap, selected, ThemePreviewCard (+1 more)

### Community 76 - "backendProvider"
Cohesion: 0.07
Nodes (33): backendProvider, login, resumeWithToken, build, MenuCategoriesScreen, _addEntry, _editEntry, _busy (+25 more)

### Community 77 - "nb_group.dart"
Cohesion: 0.12
Nodes (15): build, child, children, danger, icon, NbGroup, NbListRow, NbRow (+7 more)

### Community 78 - "ConsumerState"
Cohesion: 0.08
Nodes (18): startFromBackupProvider, build, createState, dispose, KitchenSetupScreen, _KitchenSetupScreenState, _onTab, _tabs (+10 more)

### Community 79 - "shape.dart"
Cohesion: 0.14
Nodes (11): borderBase, borderBold, borderHair, chromeBlur, chromeOpacity, innerHighlight, isTranslucent, opaque (+3 more)

### Community 80 - "theme/motion.dart"
Cohesion: 0.17
Nodes (9): curve, entrance, fast, isStill, normal, page, pressScale, staggerStep (+1 more)

### Community 81 - "List"
Cohesion: 0.20
Nodes (6): actions, body, build, icon, NoticeScreen, title

### Community 82 - "fake_backend.dart"
Cohesion: 0.18
Nodes (6): Role, backend, db, deviceRole, login, signInAdmin

### Community 83 - "locale_store.dart"
Cohesion: 0.12
Nodes (13): build, LocaleController, localeStoreProvider, AppLocaleId, code, fromCode, _key, locale (+5 more)

### Community 84 - "bool get"
Cohesion: 0.20
Nodes (7): canBill, canScan, canUsePurchaseSchedule, fromWire, isAdmin, scanner, wire

### Community 85 - "refunds_screen.dart"
Cohesion: 0.31
Nodes (8): menuCategoriesProvider, build, _CategoryField, _activeMembersProvider, build, _form, _refundsProvider, RefundsScreen

### Community 86 - "topup_history_screen.dart"
Cohesion: 0.22
Nodes (8): backend, build, _confirmReverse, _History, _historyProvider, members, TopupHistoryTab, topups

### Community 87 - "typography.dart"
Cohesion: 0.22
Nodes (7): body, display, family, heading, label, onColor, scale

### Community 88 - "setup_screens_test.dart"
Cohesion: 0.10
Nodes (7): device, main, screens, app, main, main, resolve

### Community 89 - "l10n_parity_test.dart"
Cohesion: 0.13
Nodes (8): didChangeAppLifecycleState, LifecycleLogger, _log, en, keys, load, main, variables

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

### Community 94 - "DEVELOPER_GUIDE.md"
Cohesion: 0.30
Nodes (6): 0008 — Feature-grouped folders; tests mirror lib/, PRD — Tiffin unit-based canteen coupon system, PRD §14 Neobrutalism visual theme, Documentation, Tiffin User Guide (v3), Tiffin canteen coupon system (v3)

### Community 95 - "error_report.dart"
Cohesion: 0.17
Nodes (10): _alphabet, chunk, ErrorNotice, _log, message, newReferenceCode, _random, ref (+2 more)

### Community 96 - "canteens.dart"
Cohesion: 0.10
Nodes (16): addSignInMethod, _alphabet, _auth, CanteenService, codeLength, _db, _log, nameOf (+8 more)

### Community 97 - "ingredients_screen.dart"
Cohesion: 0.06
Nodes (32): Ingredient, _adjustStock, build, ingredientsProvider, IngredientsTab, lowAt, name, _num (+24 more)

### Community 99 - "meal_type.dart"
Cohesion: 0.29
Nodes (4): brunch, fromWire, MealType, wire

### Community 100 - "menu_service.dart"
Cohesion: 0.12
Nodes (14): addEntry, _categories, createCategory, deleteCategory, deleteEntry, _entries, entryId, listCategories (+6 more)

### Community 101 - "Tiffin at a glance"
Cohesion: 0.20
Nodes (10): Controls, and what to know, Decisions already made, Glossary, How a day works, How it is built, Tiffin at a glance, What it is, Where it stands (+2 more)

### Community 102 - "canteen_book.dart"
Cohesion: 0.09
Nodes (20): sharedPreferencesProvider, activate, active, activeCode, build, CanteenBook, CanteenBookState, canteens (+12 more)

### Community 103 - "@immutable"
Cohesion: 0.25
Nodes (6): SyncState, MotionTokens, TiffinPalette, TiffinShape, TiffinTokens, TiffinTypography

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
Cohesion: 0.33
Nodes (7): ProfitSummary, build, _expensesProvider, ExpensesScreen, _form, _stat, _summaryProvider

### Community 122 - "clay.dart"
Cohesion: 0.25
Nodes (6): buildClay, dark, ground, ink, _light, palette

### Community 123 - "package:flutter/material.dart"
Cohesion: 0.25
Nodes (6): buildClean, dark, ground, ink, _light, palette

### Community 124 - "xlsx_writer.dart"
Cohesion: 0.09
Nodes (19): add, build, _columnName, _contentTypes, _escape, headers, name, _rootRels (+11 more)

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
Cohesion: 0.25
Nodes (6): buildFrost, dark, ground, ink, _light, palette

### Community 131 - "String?"
Cohesion: 0.29
Nodes (3): BrandSplash, build, message

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

## Knowledge Gaps
- **1576 isolated node(s):** `XCTest`, `error`, `stack`, `onRetry`, `appearancePolicyProvider` (+1571 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1820 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `String?`, `package:flutter_riverpod/flutter_riverpod.dart`, `../../core/errors.dart`, `member.dart`, `nb_button.dart`, `../theme/tokens.dart`, `../../l10n/app_localizations.dart`, `app_gate.dart`, `State`, `StatelessWidget`, `theme_preview.dart`, `ConsumerState`, `theme/motion.dart`, `List`, `setup_screens_test.dart`, `dart:typed_data`, `error_report.dart`, `ingredients_screen.dart`, `provider_buttons.dart`, `package:flutter/material.dart`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **What connects `XCTest`, `error`, `stack` to the rest of the system?**
  _1576 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `backend.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.019417475728155338 - nodes in this community are weakly interconnected._
- **Why does `_` connect `_` to `nb_button.dart`, `String?`, `@immutable`, `TiffinTokensContext`, `package:flutter/material.dart`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Should `ledger.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Why does `Store` connect `../../core/errors.dart` to `backend.dart`, `user_service.dart`, `access.dart`, `menu_service.dart`, `cache_warmer.dart`, `auth_service.dart`, `member_service.dart`, `backup_service.dart`, `store.dart`, `settings_service.dart`, `topup_service.dart`, `notification_service.dart`, `providers.dart`, `report_service.dart`, `ingredient_service.dart`, `scan_service.dart`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Should `_` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._