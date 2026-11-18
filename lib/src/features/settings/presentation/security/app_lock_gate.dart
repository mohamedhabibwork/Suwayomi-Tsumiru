// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../utils/analytics/firebase_telemetry_service.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/tsumiru_logo.dart';
import '../../../auth/data/auth_credentials_store.dart';
import '../../../auth/presentation/face_id_auth_service.dart';
import '../browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import 'security_settings_provider.dart';

class AppLockGate extends HookConsumerWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appLockEnabledProvider) ?? false;
    final storedPin = ref.watch(appLockPinProvider) ?? '';
    final unlocked = ref.watch(appLockSessionUnlockedProvider);
    final timeoutSeconds = ref.watch(appLockTimeoutSecondsProvider) ?? 0;
    final blockScreenshots = ref.watch(blockScreenshotsProvider) ?? true;
    final screenCaptured = useState(false);
    final appBackgrounded = useState(false);
    final backgroundedAt = useRef<DateTime?>(null);

    useEffect(() {
      syncNativeScreenshotProtection(blockScreenshots);
      if (blockScreenshots) {
        queryNativeScreenCaptured().then((captured) {
          if (context.mounted) screenCaptured.value = captured;
        });
      } else {
        screenCaptured.value = false;
      }
      kSecurityChannel.setMethodCallHandler((call) async {
        if (call.method == 'onScreenCaptureChanged') {
          final captured = (call.arguments as Map?)?['captured'] == true;
          if (context.mounted) screenCaptured.value = captured;
        } else if (call.method == 'onScreenshotTaken') {
          AppTelemetry.logEvent('security_screenshot_blocked');
          if (context.mounted && (ref.read(blockScreenshotsProvider) ?? true)) {
            ref
                .read(toastProvider)
                ?.show('Screenshots & screen recording are restricted');
          }
        }
      });
      return null;
    }, [blockScreenshots]);

    useEffect(() {
      void handleBackground() {
        appBackgrounded.value = true;
        backgroundedAt.value ??= DateTime.now();
        lockNsfwOnAppClose(ref);
        if (timeoutSeconds <= 0 &&
            (ref.read(appLockEnabledProvider) ?? false) &&
            (ref.read(appLockPinProvider) ?? '').length == 4) {
          ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(false);
        }
      }

      void handleForeground() {
        appBackgrounded.value = false;
        if (blockScreenshots) {
          syncNativeScreenshotProtection(true);
          queryNativeScreenCaptured().then((captured) {
            if (context.mounted) screenCaptured.value = captured;
          });
        }
        final pausedAt = backgroundedAt.value;
        backgroundedAt.value = null;
        if (pausedAt == null) return;
        final elapsed = DateTime.now().difference(pausedAt).inSeconds;
        if (elapsed >= timeoutSeconds) {
          ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(false);
        }
      }

      final listener = AppLifecycleListener(
        onPause: handleBackground,
        onHide: handleBackground,
        onDetach: () => lockNsfwOnAppClose(ref),
        onShow: handleForeground,
        onResume: handleForeground,
      );
      return listener.dispose;
    }, [timeoutSeconds, blockScreenshots]);

    final mustLock = enabled && storedPin.length == 4 && !unlocked;
    final showBlackScreen =
        blockScreenshots && (screenCaptured.value || appBackgrounded.value);
    if (!mustLock && !showBlackScreen) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (mustLock) const _PasscodeLockOverlay(),
        if (showBlackScreen)
          const Material(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FluentIcons.shield_lock_24_regular,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Screen Recording & Capture Restricted',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PasscodeLockOverlay extends HookConsumerWidget {
  const _PasscodeLockOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storedPin = ref.watch(appLockPinProvider) ?? '';
    final failedAttempts = ref.watch(appLockFailedAttemptsProvider) ?? 0;
    final cooldownUntilMs = ref.watch(appLockCooldownUntilMsProvider) ?? 0;
    final entered = useState('');
    final nowMs = useState(DateTime.now().millisecondsSinceEpoch);
    final bioBusy = useState(false);

    final remainingCooldown =
        ((cooldownUntilMs - nowMs.value) / 1000).ceil().clamp(0, 3600);

    useEffect(() {
      if (remainingCooldown <= 0) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        nowMs.value = DateTime.now().millisecondsSinceEpoch;
      });
      return timer.cancel;
    }, [cooldownUntilMs, remainingCooldown > 0]);

    Future<void> unlockWithBiometrics() async {
      if (bioBusy.value || remainingCooldown > 0) return;
      bioBusy.value = true;
      try {
        final ok = await authenticateWithFaceId(
          reason: 'Authenticate with Face ID to unlock Mangaka FC',
        );
        if (!context.mounted) return;
        if (ok) {
          ref.read(appLockFailedAttemptsProvider.notifier).update(0);
          ref.read(appLockCooldownUntilMsProvider.notifier).update(0);
          ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
          AppTelemetry.logEvent('app_lock_unlocked', {'method': 'face_id'});
        }
      } finally {
        if (context.mounted) bioBusy.value = false;
      }
    }

    void onDigit(String digit) {
      if (remainingCooldown > 0 || entered.value.length >= 4) return;
      final next = '${entered.value}$digit';
      entered.value = next;
      if (next.length == 4) {
        if (next == storedPin) {
          ref.read(appLockFailedAttemptsProvider.notifier).update(0);
          ref.read(appLockCooldownUntilMsProvider.notifier).update(0);
          ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
          AppTelemetry.logEvent('app_lock_unlocked', {'method': 'pin'});
        } else {
          final newFailures = failedAttempts + 1;
          ref.read(appLockFailedAttemptsProvider.notifier).update(newFailures);
          final cooldownSec = computeLockCooldownSeconds(newFailures);
          if (cooldownSec > 0) {
            final until =
                DateTime.now().millisecondsSinceEpoch + cooldownSec * 1000;
            ref.read(appLockCooldownUntilMsProvider.notifier).update(until);
            nowMs.value = DateTime.now().millisecondsSinceEpoch;
          }
          entered.value = '';
          AppTelemetry.logEvent('app_lock_failed', {'attempts': newFailures});
        }
      }
    }

    void onBackspace() {
      if (entered.value.isNotEmpty) {
        entered.value = entered.value.substring(0, entered.value.length - 1);
      }
    }

    Future<void> resetViaSignOut() async {
      ref.read(appLockEnabledProvider.notifier).update(false);
      ref.read(appLockPinProvider.notifier).update('');
      ref.read(appLockFailedAttemptsProvider.notifier).update(0);
      ref.read(appLockCooldownUntilMsProvider.notifier).update(0);
      ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
      await ref.read(authCredentialsStoreProvider.notifier).clearUiLoginTokens();
    }

    Widget buildKeyRow(List<Widget> children) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        children[0],
        const SizedBox(width: 16),
        children[1],
        const SizedBox(width: 16),
        children[2],
      ],
    );

    final cs = context.theme.colorScheme;
    return Material(
      color: cs.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TsumiruLogo(size: 72),
                const SizedBox(height: 16),
                Text(
                  'Enter Passcode',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (remainingCooldown > 0)
                  Text(
                    'Too many attempts. Try again in ${remainingCooldown}s',
                    style: TextStyle(color: cs.error),
                  )
                else if (failedAttempts > 0)
                  Text(
                    'Incorrect passcode ($failedAttempts failed)',
                    style: TextStyle(color: cs.error),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < entered.value.length
                              ? cs.primary
                              : cs.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                buildKeyRow([
                  for (final d in ['1', '2', '3'])
                    _PinKeyButton(
                      label: d,
                      onTap: remainingCooldown > 0 ? null : () => onDigit(d),
                    ),
                ]),
                const SizedBox(height: 16),
                buildKeyRow([
                  for (final d in ['4', '5', '6'])
                    _PinKeyButton(
                      label: d,
                      onTap: remainingCooldown > 0 ? null : () => onDigit(d),
                    ),
                ]),
                const SizedBox(height: 16),
                buildKeyRow([
                  for (final d in ['7', '8', '9'])
                    _PinKeyButton(
                      label: d,
                      onTap: remainingCooldown > 0 ? null : () => onDigit(d),
                    ),
                ]),
                const SizedBox(height: 16),
                buildKeyRow([
                  SizedBox(
                    width: 72,
                    height: 64,
                    child: IconButton(
                      tooltip: 'Unlock with Face ID',
                      onPressed:
                          remainingCooldown > 0 ? null : unlockWithBiometrics,
                      icon: const Icon(FluentIcons.person_passkey_24_regular),
                    ),
                  ),
                  _PinKeyButton(
                    label: '0',
                    onTap: remainingCooldown > 0 ? null : () => onDigit('0'),
                  ),
                  SizedBox(
                    width: 72,
                    height: 64,
                    child: IconButton(
                      tooltip: 'Backspace',
                      onPressed: onBackspace,
                      icon: const Icon(FluentIcons.backspace_24_regular),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed:
                      remainingCooldown > 0 ? null : unlockWithBiometrics,
                  icon: const Icon(FluentIcons.person_passkey_24_regular),
                  label: const Text('Unlock with Face ID'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: resetViaSignOut,
                  child: const Text('Forgot PIN? Sign out to reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  const _PinKeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 64,
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
