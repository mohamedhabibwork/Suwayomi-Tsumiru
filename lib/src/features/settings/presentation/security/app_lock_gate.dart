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

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/tsumiru_logo.dart';
import '../../../auth/data/auth_credentials_store.dart';
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
    final backgroundedAt = useRef<DateTime?>(null);

    useEffect(() {
      final listener = AppLifecycleListener(
        onPause: () {
          backgroundedAt.value = DateTime.now();
          lockNsfwOnAppClose(ref);
        },
        onHide: () => lockNsfwOnAppClose(ref),
        onDetach: () => lockNsfwOnAppClose(ref),
        onResume: () {
          final pausedAt = backgroundedAt.value;
          backgroundedAt.value = null;
          if (pausedAt == null) return;
          final elapsed = DateTime.now().difference(pausedAt).inSeconds;
          if (elapsed >= timeoutSeconds) {
            ref
                .read(appLockSessionUnlockedProvider.notifier)
                .setUnlocked(false);
          }
        },
      );
      return listener.dispose;
    }, [timeoutSeconds]);

    final mustLock = enabled && storedPin.length == 4 && !unlocked;
    if (!mustLock) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const _PasscodeLockOverlay(),
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

    final remainingCooldown =
        ((cooldownUntilMs - nowMs.value) / 1000).ceil().clamp(0, 3600);

    useEffect(() {
      if (remainingCooldown <= 0) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        nowMs.value = DateTime.now().millisecondsSinceEpoch;
      });
      return timer.cancel;
    }, [cooldownUntilMs, remainingCooldown > 0]);

    void onDigit(String digit) {
      if (remainingCooldown > 0 || entered.value.length >= 4) return;
      final next = '${entered.value}$digit';
      entered.value = next;
      if (next.length == 4) {
        if (next == storedPin) {
          ref.read(appLockFailedAttemptsProvider.notifier).update(0);
          ref.read(appLockCooldownUntilMsProvider.notifier).update(0);
          ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
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
                SizedBox(
                  width: 260,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                        _PinKeyButton(
                          label: d,
                          onTap: remainingCooldown > 0 ? null : () => onDigit(d),
                        ),
                      const SizedBox(width: 72, height: 64),
                      _PinKeyButton(
                        label: '0',
                        onTap: remainingCooldown > 0 ? null : () => onDigit('0'),
                      ),
                      SizedBox(
                        width: 72,
                        height: 64,
                        child: IconButton(
                          onPressed: onBackspace,
                          icon: const Icon(FluentIcons.backspace_24_regular),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
