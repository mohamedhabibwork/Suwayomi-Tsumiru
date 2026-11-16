# Tachimanga Free Features & Per-User Customization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all remaining Tachimanga (`v4.13`–`v5.4`) and Tachimanga Premium features for free in `Mangaka` (`Suwayomi-Tsumiru`), with per-user customization scoping and server `GlobalMetaTable` sync.

**Architecture:** All new preferences live in `enum DBKeys` (`lib/src/constants/db_keys.dart`) and are scoped per signed-in user (`u_${userId}_${key.name}`) via `SharedPreferenceClientMixin` / `SharedPreferenceEnumClientMixin`, with cross-device per-user backup in `GlobalMetaTable` (`key: "mangaka_user_prefs"`). Security (`AppLockGate` + `SecuritySettingsDialog`), Reader (`pageCurlTransition`, `autoScrollSleepTimer`, hold-to-pause/drag-speed HUD, toolbar quick actions), Library (`BulkTrackingDialog`), Migration (`migrationKeepOriginal`), and Navigation (`hideBottomTabLabels`) integrate directly into existing Riverpod controllers and screens.

**Tech Stack:** Flutter / Dart (`>=3.9.0`), `hooks_riverpod`, `shared_preferences`, `graphql` (`Suwayomi-Server` GraphQL API).

**Spec:** `docs/superpowers/specs/2026-11-16-tachimanga-free-features-design.md`

## Global Constraints

- Zero paywalls, subscriptions, or trial limits — all features are 100% free.
- No new native iOS/Android entitlements (`Info.plist` / provisioning profile for `app.firstcallmedical.manga`, Team `47S9UJ6UZP` must remain unchanged).
- Connection-level `DBKeys` (`serverUrl`, `serverExternalUrl`, `serverLanUrl`, `serverPort`, `serverPortToggle`, `authType`, `authUsername`, `basicCredentials`, `onboardingComplete`) stay device-scoped; all customization `DBKeys` scope to `u_${userId}_${key.name}` when signed in.
- Must pass `dart analyze` with zero errors and unit tests via `flutter test`.

## Review Focus

1. **Switching between two user accounts on the same device**: User A's theme, reader mode, and app lock PIN must not leak into User B's session (`u_1_...` vs `u_2_...`).
2. **Force-quitting during App Lock cooldown**: `appLockFailedAttempts` and `appLockCooldownUntilMs` must persist in `DBKeys` so reopening the app still enforces the active cooldown timer.
3. **Manual scrolling while Auto-Scroll is active**: Pointer-down must immediately pause auto-scroll (`holdPaused = true`) and pointer-up/cancel must resume it so vertical drag scrolling never fights the timer.
4. **Disable Content Sharing toggle**: When `disableContentSharing` is `true`, OS share buttons (`SharePlus`) are hidden/blocked while local Copy and Save to gallery continue to work.
5. **Page-Curl with Reduce Motion enabled**: When `context.reduceMotion` is `true` or `pageCurlTransition` is `false`, horizontal page turns fall back cleanly without 3D perspective distortion.

---

### Task 1: Per-User `DBKeys` Scoping & New Preference Keys

**Files:**
- Modify: `lib/src/constants/db_keys.dart`
- Modify: `lib/src/utils/mixin/shared_preferences_client_mixin.dart`
- Create: `test/utils/per_user_preferences_test.dart`

**Interfaces:**
- Produces:
  - New `DBKeys`: `appLockEnabled(false)`, `appLockPin('')`, `appLockTimeoutSeconds(0)`, `appLockFailedAttempts(0)`, `appLockCooldownUntilMs(0)`, `disableContentSharing(false)`, `pageCurlTransition(false)`, `autoScrollSleepTimerMinutes(0)`, `migrationKeepOriginal(false)`, `hideBottomTabLabels(false)`.
  - `String scopedPrefKey(DBKeys key, int? userId)` in `lib/src/utils/mixin/shared_preferences_client_mixin.dart`.

- [ ] **Step 1: Write the failing test in `test/utils/per_user_preferences_test.dart`**
  - Verify `scopedPrefKey(DBKeys.appTheme, null) == 'appTheme'`, `scopedPrefKey(DBKeys.appTheme, 42) == 'u_42_appTheme'`, and `scopedPrefKey(DBKeys.serverUrl, 42) == 'serverUrl'`.
- [ ] **Step 2: Run test to verify it fails**
  - Run: `flutter test test/utils/per_user_preferences_test.dart`
- [ ] **Step 3: Implement `DBKeys` additions and `scopedPrefKey` in `db_keys.dart` and `shared_preferences_client_mixin.dart`**
  - Watch `currentAccountProvider` in `SharedPreferenceClientMixin.initialize` and `SharedPreferenceEnumClientMixin.initialize` to compute `_key = scopedPrefKey(key, account?.id)`.
- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/utils/per_user_preferences_test.dart`
- [ ] **Step 5: Commit**
  - `git commit -m "feat: add Tachimanga DBKeys and per-user preference scoping"`

---

### Task 2: Security Settings, Passcode App Lock Gate & Disable Content Sharing

**Files:**
- Create: `lib/src/features/settings/presentation/security/security_settings_provider.dart`
- Create: `lib/src/features/settings/presentation/security/security_settings_dialog.dart`
- Create: `lib/src/features/settings/presentation/security/app_lock_gate.dart`
- Modify: `lib/src/features/settings/presentation/more/more_screen.dart`
- Modify: `lib/src/tsumiru_app.dart`
- Modify: `lib/src/features/manga_book/presentation/reader/widgets/chrome/reader_page_actions_sheet.dart`
- Modify: `lib/src/features/manga_book/presentation/manga_details/manga_details_screen.dart`
- Create: `test/src/features/settings/security_lock_cooldown_test.dart`

**Interfaces:**
- Consumes: `DBKeys.appLockEnabled`, `DBKeys.appLockPin`, `DBKeys.appLockTimeoutSeconds`, `DBKeys.appLockFailedAttempts`, `DBKeys.appLockCooldownUntilMs`, `DBKeys.disableContentSharing`.
- Produces: `appLockEnabledProvider`, `disableContentSharingProvider`, `computeLockCooldownSeconds(int failedAttempts)`, `AppLockGate`, `showSecuritySettingsDialog(BuildContext context)`.

- [ ] **Step 1: Write the failing test in `test/src/features/settings/security_lock_cooldown_test.dart`**
  - Verify `computeLockCooldownSeconds` returns `0` for `1..2` failures, `5` for `3`, `15` for `4`, `30` for `5`, and `60` for `>=6`.
- [ ] **Step 2: Run test to verify it fails**
  - Run: `flutter test test/src/features/settings/security_lock_cooldown_test.dart`
- [ ] **Step 3: Implement `security_settings_provider.dart`, `security_settings_dialog.dart`, `app_lock_gate.dart`, and wire into `MoreScreen`, `TsumiruApp`, and share actions**
  - Also add the outlined `Incognito` pill indicator in `MoreScreen` when `incognitoModeProvider` is active, and hide `SharePlus` triggers when `disableContentSharingProvider` is `true`.
- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/src/features/settings/security_lock_cooldown_test.dart`
- [ ] **Step 5: Commit**
  - `git commit -m "feat: add Passcode App Lock, Disable Content Sharing, and Security settings"`

---

### Task 3: Reader Page-Curl Transition, Auto-Scroll Sleep Timer, Hold-to-Pause/Speed HUD & Quick Actions

**Files:**
- Modify: `lib/src/features/manga_book/presentation/reader/controller/auto_scroll_controller.dart`
- Modify: `lib/src/features/manga_book/presentation/reader/widgets/chrome/reader_utils_bar.dart`
- Modify: `lib/src/features/manga_book/presentation/reader/widgets/chrome/reader_bottom_controls.dart`
- Modify: `lib/src/features/manga_book/presentation/reader/widgets/chrome/tabs/reading_mode_tab.dart`
- Modify: `lib/src/features/manga_book/presentation/reader/widgets/reader_mode/paged_reader_viewport.dart`
- Modify: `lib/src/features/manga_book/presentation/reader/widgets/reader_wrapper.dart`
- Create: `test/src/features/manga_book/auto_scroll_timer_test.dart`

**Interfaces:**
- Consumes: `DBKeys.pageCurlTransition`, `DBKeys.autoScrollSleepTimerMinutes`.
- Produces: `pageCurlTransitionProvider`, `autoScrollSleepTimerMinutesProvider`, `autoScrollHoldPausedProvider`, `autoScrollRemainingSecondsProvider`, `applyPageCurlTransform(Widget child, double pageDelta, {required bool enabled})`.

- [ ] **Step 1: Write the failing test in `test/src/features/manga_book/auto_scroll_timer_test.dart`**
  - Verify `AutoScrollHoldPaused` pauses auto-scroll ticks without clearing `AutoScrollActive`, and sleep timer stops `AutoScrollActive` when countdown reaches `0`.
- [ ] **Step 2: Run test to verify it fails**
  - Run: `flutter test test/src/features/manga_book/auto_scroll_timer_test.dart`
- [ ] **Step 3: Implement auto-scroll sleep timer, hold-to-pause + vertical drag speed HUD, page-curl transition, and reader quick actions (*Mark Previous Chapter Read*, *Delete Download*, *Close Reader*)**
- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/src/features/manga_book/auto_scroll_timer_test.dart`
- [ ] **Step 5: Commit**
  - `git commit -m "feat: add page-curl transition, auto-scroll timer/HUD, and reader quick actions"`

---

### Task 4: Bulk Tracking in Library Selection, Saved Migration Keep-Original & Hide Bottom Tab Labels

**Files:**
- Create: `lib/src/features/library/presentation/library/widgets/bulk_tracking_dialog.dart`
- Modify: `lib/src/features/library/presentation/library/library_screen.dart`
- Modify: `lib/src/features/migration/presentation/screens/migration_bulk_config_screen.dart`
- Modify: `lib/src/features/migration/presentation/widgets/migration_config_sheet.dart`
- Modify: `lib/src/widgets/shell/small_screen_navigation_bar.dart`
- Modify: `lib/src/features/settings/presentation/appearance/appearance_screen.dart`
- Create: `test/src/features/migration/migration_keep_original_test.dart`

**Interfaces:**
- Consumes: `DBKeys.migrationKeepOriginal`, `DBKeys.hideBottomTabLabels`.
- Produces: `migrationKeepOriginalProvider`, `hideBottomTabLabelsProvider`, `showBulkTrackingDialog(BuildContext context, List<MangaDto> selectedMangas)`.

- [ ] **Step 1: Write the failing test in `test/src/features/migration/migration_keep_original_test.dart`**
  - Verify `migrationKeepOriginalProvider` defaults to `false`, updates in `SharedPreferences`, and maps to `deleteSource: !keepOriginal`.
- [ ] **Step 2: Run test to verify it fails**
  - Run: `flutter test test/src/features/migration/migration_keep_original_test.dart`
- [ ] **Step 3: Implement `BulkTrackingDialog` in Library selection bar, bind `migrationKeepOriginalProvider` in migration screens, and wire `hideBottomTabLabelsProvider` in `SmallScreenNavigationBar` and `AppearanceScreen`**
- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/src/features/migration/migration_keep_original_test.dart`
- [ ] **Step 5: Commit, push to GitHub, and build/upload updated IPA to TestFlight**
