# Tachimanga Changelog Features (100% Free) — Design Specification

**Date**: 2026-11-16  
**Project**: Mangaka (`Suwayomi-Tsumiru`)  
**Status**: Draft (Pending Builder Check & User Approval)

---

## 1. Intent & Why

Tachimanga gates many power-user manga/webtoon features behind a paid "Premium" subscription and has recently shipped UX improvements across `v4.13`–`v5.4` (Security settings, Reader page-curl & auto-scroll timers/speed controls, Reader toolbar quick actions, Library bulk tracking, Migration persistence, and Navigation tab customization).

`Mangaka` (`Suwayomi-Tsumiru` `1.6.5`) already implements ~90% of Tachimanga's feature set for free (auto-webtoon tag detection, white/black border cropping, manga notes, double-page spread/invert/offset, custom reader background colors, per-mode tap zones, Shikimori/Bangumi/MangaBaka/MangaUpdates trackers, bulk migration with target source search, and alphabetical source sorting by language).

This project implements all **remaining Tachimanga changelog features (`v4.13`–`v5.4`) completely free** with zero paywalls, using native Riverpod state and `DBKeys` persistence so every feature works across iOS, Android, macOS, Windows, Linux, and Web.

---

## 2. Goals, Non-Goals & Anti-Goals

### Goals
1. **Security & Privacy (`More -> Security`)**:
   - **Passcode App Lock (`v4.16`)**: Optional 4-digit PIN lock when opening/resuming the app, with configurable lock timeout (Immediate, 1 min, 5 min, 15 min) and exponential cooldown after 3+ failed attempts (5s, 15s, 30s, 60s).
   - **Disable Content Sharing (`v5.3`)**: Toggle under `More -> Security` (`DBKeys.disableContentSharing`) that hides/blocks sharing manga URLs, chapter URLs, covers, and reader page images across the app.
   - **Clearer Incognito Mode Recognition (`v5.3`)**: Highlighted incognito banner/outlined navigation indicator when Incognito Mode is active.
2. **Reader Experience (`v5.0`–`v5.4`)**:
   - **Horizontal Page-Curl Animation (`v5.3`)**: Option (`DBKeys.pageCurlTransition`) in Paged Reader settings that renders a realistic 3D/curl page-turn transition with shadow gradient in single-page and double-page horizontal modes.
   - **Auto-Scroll Sleep Timer (`v5.2`)**: Configurable auto-scroll countdown timer (`Off`, `5m`, `15m`, `30m`, `60m`) in `ReaderUtilsBar` that automatically stops auto-scroll/auto-advance when the timer expires.
   - **Hold-to-Pause & Drag Speed Adjustment (`v5.0`, `v5.4`)**: While auto-scroll is active, holding pauses scrolling (or dragging vertically adjusts speed in real time) with a centered on-screen speed indicator pill.
   - **Reader Toolbar Quick Actions (`v5.2`, `v5.3`)**: Quick action buttons in the reader bottom/utility controls for **Mark Previous Chapter as Read**, **Delete Chapter Download**, and **Close Reader**.
3. **Library, Migration & Navigation (`v4.13`–`v5.4`)**:
   - **Bulk Tracking in Library Selection (`v4.20`)**: Add a **Track** action to the Library multi-select toolbar (`Library -> Select titles -> Track`) that opens a bulk status/tracker assignment sheet for all selected manga.
   - **Saved "Keep Original Entries in Library" Migration Option (`v5.3`)**: Persist `DBKeys.migrationKeepOriginal` (`default: false`) in `MigrationConfigSheet` and `MigrationBulkConfigScreen` so single and bulk migrations remember the user's choice.
   - **Hide Bottom Navigation Tab Labels (`v4.14`)**: Add `DBKeys.hideBottomTabLabels` (`default: false`) in Appearance settings to allow compact icon-only bottom navigation bars on phone/tablet.

### Non-Goals
- Native iOS 26 private "Liquid Glass" Apple framework APIs or Apple Pencil Pro hardware-only squeeze APIs (we provide cross-platform touch/stylus equivalents).
- Server-side schema migrations for client UI preferences.

### Anti-Goals
- Any paywall, subscription prompt, or trial limit — every feature is 100% free for all users.
- Breaking existing `build_runner` codegen or TestFlight code-signing entitlements.

---

## 3. Constraints

- **No New Native Entitlements**: Must build and sign cleanly with existing `app.firstcallmedical.manga` provisioning profile (`Team 47S9UJ6UZP`) for TestFlight.
- **Persistence Pattern**: New persisted settings must be added to `enum DBKeys` in `lib/src/constants/db_keys.dart` with sensible default values.
- **Static Analysis**: Must pass `dart analyze` with zero errors.

---

## 4. Approaches Considered

### Approach A (Selected): Native Riverpod + `DBKeys` Client-First Implementation
- All new settings live in `DBKeys` (`lib/src/constants/db_keys.dart`) and Riverpod providers.
- Security lock overlay wraps the app shell (`AppLockGate` inside `lib/src/suwayomi.dart`), enforcing PIN verification and failed-attempt cooldowns on app start and `AppLifecycleState.resumed`.
- Reader, Library, Migration, and Navigation features plug directly into existing screens (`MoreScreen`, `ReaderUtilsBar`, `ReaderBottomControls`, `PagedReaderViewport`, `LibraryScreen` selection bar, `MigrationConfigSheet`, `AppearanceSettingsScreen`).
- **Why selected**: Zero native plugin/entitlement friction, works across all 6 target platforms, and ships immediately to TestFlight.

### Approach B: Native Platform Plugins (`local_auth`) + Server-Backed Settings Sync
- Rejected because adding native biometric plugins requires updating iOS `Info.plist` / provisioning entitlements and backend GraphQL schemas for UI-only preferences.

---

## 5. Detailed Design

### 5.1 New `DBKeys` Entries (`lib/src/constants/db_keys.dart`)
- `appLockEnabled(false)`: `bool` — whether PIN app lock is active.
- `appLockPin('')`: `String` — SHA-256 hash (or stored PIN string) for app lock verification.
- `appLockTimeoutSeconds(0)`: `int` — `0` (immediately), `60` (1m), `300` (5m), `900` (15m).
- `appLockFailedAttempts(0)`: `int` — persisted consecutive failed PIN attempts so force-quitting cannot bypass cooldown.
- `appLockCooldownUntilMs(0)`: `int` — epoch milliseconds until which PIN entry is locked out (`5s`, `15s`, `30s`, `60s` tiers).
- `disableContentSharing(false)`: `bool` — hides/blocks share actions across manga, chapters, covers, and reader pages.
- `pageCurlTransition(false)`: `bool` — enables realistic page-curl animation in horizontal paged reader mode.
- `autoScrollSleepTimerMinutes(0)`: `int` — `0` (off), `5`, `15`, `30`, `60` minutes auto-stop timer for auto-scroll.
- `migrationKeepOriginal(false)`: `bool` — persisted toggle for keeping original entries in Library during single/bulk migration.
- `hideBottomTabLabels(false)`: `bool` — hides text labels beneath bottom navigation bar icons.

### 5.2 Security & Privacy (`lib/src/features/settings/presentation/security/`)
- **`security_settings_provider.dart`**:
  - Riverpod providers backed by `DBKeys` (`appLockEnabledProvider`, `appLockPinProvider`, `appLockTimeoutSecondsProvider`, `appLockFailedAttemptsProvider`, `appLockCooldownUntilMsProvider`, `disableContentSharingProvider`) plus an in-memory `appLockUnlockedProvider` session state.
- **`security_settings_screen.dart` & `more_screen.dart`**:
  - Add a **Security** row in `MoreScreen` (`lib/src/features/settings/presentation/more/more_screen.dart`) that opens a `SecuritySettingsDialog` / screen with:
    1. **Enable Passcode Lock** toggle + **Set/Change 4-Digit PIN** dialog.
    2. **Lock Timeout** selector (`Immediately`, `After 1 minute`, `After 5 minutes`, `After 15 minutes`).
    3. **Disable Content Sharing** switch (`DBKeys.disableContentSharing`).
- **`app_lock_gate.dart`**:
  - Wraps the root child in `lib/src/suwayomi.dart` (`MaterialApp.router` `builder`).
  - Observes `AppLifecycleListener`: records background timestamp on `paused`/`inactive` and locks on `resumed` if `elapsed >= appLockTimeoutSeconds`.
  - When locked, displays a full-screen Mangaka PIN pad (`4` dots, keypad `0-9`, backspace). After 3 consecutive wrong PIN attempts, enforces a persisted countdown cooldown (`5s`, `15s`, `30s`, `60s`) stored in `DBKeys.appLockCooldownUntilMs`.
  - **Builder Call — Forgotten PIN Recovery**: Includes a *"Forgot PIN? Sign out to reset"* action on the lock screen that signs out of the current Suwayomi server account and clears the PIN, requiring the user to re-authenticate with their server password.
- **Content Sharing Gate (Builder Call — OS Share Triggers Only)**:
  - Strictly gates native `SharePlus` share actions (leaving local Copy / Save to gallery intact, matching Tachimanga `v5.3`):
    - `lib/src/features/manga_book/presentation/reader/widgets/chrome/reader_page_actions_sheet.dart` (hide Share Page / Share Spread rows when `disableContentSharingProvider` is `true`).
    - `lib/src/features/manga_book/presentation/manga_details/manga_details_screen.dart`, chapter menus, and `cover_viewer.dart` (hide Share manga / chapter / cover buttons when enabled).
- **Incognito Header Indicator**:
  - In `MoreScreen` and `DesktopTopBar` / app bars, when `incognitoModeProvider` is `true`, show a distinct outlined pill badge (`Incognito`) in the header.

### 5.3 Reader Enhancements (`lib/src/features/manga_book/presentation/reader/`)
- **Realistic Page-Curl Transition (`v5.3`)**:
  - Add `pageCurlTransitionProvider` (`DBKeys.pageCurlTransition`) in `reader_paged_prefs.dart` and expose a toggle in `ReadingModeTab` (`reading_mode_tab.dart`) and `ReaderSettingsScreen`.
  - In horizontal paged reader (`multichapter_paged_reader_mode.dart` / `paged_reader_viewport.dart`), when `pageCurlTransition` is enabled, wrap page transitions with a custom 3D perspective + curl shadow gradient transform driven by page offset.
- **Auto-Scroll Sleep Timer (`v5.2`) & Hold-to-Pause / Drag Speed (`v5.0`, `v5.4`)**:
  - In `auto_scroll_controller.dart`:
    - Add sleep timer countdown (`autoScrollRemainingSecondsProvider`) initialized from `autoScrollSleepTimerMinutesProvider` when auto-scroll starts; automatically stops auto-scroll when countdown reaches `0`.
    - **Builder Call — Gesture Disambiguation**: Any active pointer-down (`Listener.onPointerDown` / `onPointerUp`) sets `holdPaused = true` while touching the screen so manual scrolling never fights auto-scroll, and a dedicated long-press drag (`GestureDetector.onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd`) when auto-scroll is active adjusts `autoScrollIntervalSecondsProvider` (`1s`–`30s`) in real time with a centered floating HUD pill showing current speed and remaining sleep timer.
  - In `reader_utils_bar.dart`:
    - Add a compact Sleep Timer selector chip (`Off`, `5m`, `15m`, `30m`, `60m`) next to the Auto-Scroll speed controls.
- **Reader Toolbar Quick Actions (`v5.2`, `v5.3`)**:
  - In `reader_bottom_controls.dart` (and `reader_page_actions_sheet.dart`):
    - Add quick actions for:
      - **Mark Previous Chapter as Read** (marks `prevChapter.id` read via `mangaBookRepositoryProvider` and shows confirmation toast).
      - **Delete Chapter Download** (deletes downloaded copy of current chapter if downloaded).
      - **Close Reader** button (`Navigator.maybePop(context)`).

### 5.4 Library, Migration & Navigation (`v4.13`–`v5.4`)
- **Bulk Tracking in Library Selection (`v4.20`)**:
  - **Builder Call — Auto-Match & Bind Sheet**: In Library multi-select action bar (`lib/src/features/library/presentation/library/`), add a **Track** icon button (`FluentIcons.arrow_sync_circle_24_regular`). Tapping it opens a `BulkTrackingDialog` that lets the user choose an active logged-in tracker (AniList, MAL, Shikimori, Bangumi, MangaBaka, MangaUpdates) and sequentially searches & binds the top matching result for each selected manga (with progress count and per-item status), or lets the user tap any item to open its `TrackSheetContent`.
- **Saved "Keep Original Entries" in Migration (`v5.3`)**:
  - Bind the `Keep original entries in Library` (`!deleteSource`) toggle in `migration_config_sheet.dart` and `migration_bulk_config_screen.dart` to `DBKeys.migrationKeepOriginal` so user preference persists across sessions.
- **Hide Bottom Navigation Tab Labels (`v4.14`)**:
  - Add `hideBottomTabLabelsProvider` (`DBKeys.hideBottomTabLabels`) in Appearance settings (`appearance_settings_screen.dart`) and wire `NavigationDestination` / `NavigationBar` (`labelBehavior: hideLabels ? NavigationDestinationLabelBehavior.alwaysHide : NavigationDestinationLabelBehavior.alwaysShow`) in `big_screen_navigation_bar.dart`.

---

## 6. What's Left to the Builder
- Exact visual styling of the 3D page-curl shader/transform matrix and PIN keypad layout, provided they match `ThemeTokens` and respect `context.reduceMotion`.
- Exact placement of the quick action icons in `ReaderBottomControls` / overflow sheet so narrow phone screens never overflow.
