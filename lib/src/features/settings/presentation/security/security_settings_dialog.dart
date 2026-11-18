// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../utils/analytics/firebase_telemetry_service.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/motion/reduce_motion.dart';
import '../../../../widgets/compact_switch.dart';
import '../../../../widgets/popup_widgets/pop_button.dart';
import '../../../auth/presentation/face_id_auth_service.dart';
import '../browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import 'security_settings_provider.dart';

Future<void> showSecuritySettingsDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const SecuritySettingsDialog(),
      animationStyle: context.motionStyle,
    );

class SecuritySettingsDialog extends HookConsumerWidget {
  const SecuritySettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(appLockEnabledProvider) ?? false;
    final pin = ref.watch(appLockPinProvider) ?? '';
    final timeout = ref.watch(appLockTimeoutSecondsProvider) ?? 0;
    final disableSharing = ref.watch(disableContentSharingProvider) ?? false;
    final blockScreenshots = ref.watch(blockScreenshotsProvider) ?? true;
    final disableSaveImages = ref.watch(disableSaveImagesProvider) ?? true;
    final autoHideNsfw = ref.watch(autoHideNsfwOnCloseProvider) ?? true;

    Future<String?> promptNewPin() => showDialog<String>(
      context: context,
      builder: (_) => const _SetPinDialog(),
      animationStyle: context.motionStyle,
    );

    Future<bool> verifyCurrentPinOrFaceId(String currentPin) async {
      if (currentPin.length != 4) return true;
      final verified = await showDialog<bool>(
        context: context,
        builder: (_) => _VerifyPinDialog(expectedPin: currentPin),
        animationStyle: context.motionStyle,
      );
      return verified == true;
    }

    Future<void> toggleAppLock(bool value) async {
      if (value) {
        if (pin.length != 4) {
          final newPin = await promptNewPin();
          if (newPin == null || newPin.length != 4) return;
          ref.read(appLockPinProvider.notifier).update(newPin);
        }
        ref.read(appLockEnabledProvider.notifier).update(true);
        ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
        AppTelemetry.logEvent('security_app_lock_toggled', {'enabled': 1});
      } else {
        final verified = await verifyCurrentPinOrFaceId(pin);
        if (!verified) return;
        ref.read(appLockEnabledProvider.notifier).update(false);
        ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
        AppTelemetry.logEvent('security_app_lock_toggled', {'enabled': 0});
      }
    }

    return AlertDialog(
      scrollable: true,
      title: const Row(
        children: [
          Icon(FluentIcons.shield_lock_24_regular),
          SizedBox(width: 8),
          Text('Security & Privacy'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.lock_closed_24_regular),
              title: const Text('Passcode App Lock'),
              subtitle: const Text(
                'Require a 4-digit PIN or Face ID when opening or resuming Mangaka',
              ),
              trailing: CompactSwitch(
                value: lockEnabled,
                onChanged: toggleAppLock,
              ),
              onTap: () => toggleAppLock(!lockEnabled),
            ),
            if (lockEnabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(FluentIcons.key_24_regular),
                title: const Text('Change Passcode'),
                trailing: const Icon(FluentIcons.chevron_right_24_regular),
                onTap: () async {
                  final verified = await verifyCurrentPinOrFaceId(pin);
                  if (!verified || !context.mounted) return;
                  final newPin = await promptNewPin();
                  if (newPin != null && newPin.length == 4) {
                    ref.read(appLockPinProvider.notifier).update(newPin);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(FluentIcons.timer_24_regular),
                title: const Text('Lock Timeout'),
                trailing: DropdownButton<int>(
                  value: const {0, 60, 300, 900}.contains(timeout)
                      ? timeout
                      : 0,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Immediately')),
                    DropdownMenuItem(value: 60, child: Text('After 1 min')),
                    DropdownMenuItem(value: 300, child: Text('After 5 min')),
                    DropdownMenuItem(value: 900, child: Text('After 15 min')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(appLockTimeoutSecondsProvider.notifier)
                          .update(v);
                    }
                  },
                ),
              ),
            ],
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.screenshot_24_regular),
              title: const Text('Black Screen on Screenshot & Recording'),
              subtitle: const Text(
                'Show a black screen when taking screenshots or recording the screen',
              ),
              trailing: CompactSwitch(
                value: blockScreenshots,
                onChanged: (v) =>
                    ref.read(blockScreenshotsProvider.notifier).update(v),
              ),
              onTap: () => ref
                  .read(blockScreenshotsProvider.notifier)
                  .update(!blockScreenshots),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.image_off_24_regular),
              title: const Text('Do Not Allow Saving Images'),
              subtitle: const Text(
                'Prevent saving or copying manga pages and cover images to device gallery',
              ),
              trailing: CompactSwitch(
                value: disableSaveImages,
                onChanged: (v) =>
                    ref.read(disableSaveImagesProvider.notifier).update(v),
              ),
              onTap: () => ref
                  .read(disableSaveImagesProvider.notifier)
                  .update(!disableSaveImages),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.share_24_regular),
              title: const Text('Disable Content Sharing'),
              subtitle: const Text(
                'Prevent accidental sharing of manga links, chapter links, covers, and page images',
              ),
              trailing: CompactSwitch(
                value: disableSharing,
                onChanged: (v) =>
                    ref.read(disableContentSharingProvider.notifier).update(v),
              ),
              onTap: () => ref
                  .read(disableContentSharingProvider.notifier)
                  .update(!disableSharing),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.eye_off_24_regular),
              title: const Text('Auto-Hide 18+ on App Close'),
              subtitle: const Text(
                'Automatically hide 18+ sources, extensions & history when closing the app',
              ),
              trailing: CompactSwitch(
                value: autoHideNsfw,
                onChanged: (v) =>
                    ref.read(autoHideNsfwOnCloseProvider.notifier).update(v),
              ),
              onTap: () => ref
                  .read(autoHideNsfwOnCloseProvider.notifier)
                  .update(!autoHideNsfw),
            ),
          ],
        ),
      ),
      actions: const [PopButton()],
    );
  }
}

class _SetPinDialog extends HookWidget {
  const _SetPinDialog();

  @override
  Widget build(BuildContext context) {
    final pinController = useTextEditingController();
    final confirmController = useTextEditingController();
    final errorText = useState<String?>(null);

    void submit() {
      final pin = pinController.text.trim();
      final confirm = confirmController.text.trim();
      if (pin.length != 4 || int.tryParse(pin) == null) {
        errorText.value = 'Please enter a valid 4-digit numeric PIN.';
        return;
      }
      if (pin != confirm) {
        errorText.value = 'PINs do not match.';
        return;
      }
      Navigator.pop(context, pin);
    }

    return AlertDialog(
      title: const Text('Set 4-Digit Passcode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'New 4-Digit PIN',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => errorText.value = null,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Confirm 4-Digit PIN',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => errorText.value = null,
            onSubmitted: (_) => submit(),
          ),
          if (errorText.value != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText.value!,
              style: TextStyle(color: context.theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        const PopButton(),
        FilledButton(
          onPressed: submit,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

class _VerifyPinDialog extends HookWidget {
  const _VerifyPinDialog({required this.expectedPin});

  final String expectedPin;

  @override
  Widget build(BuildContext context) {
    final pinController = useTextEditingController();
    final errorText = useState<String?>(null);

    void verify() {
      if (pinController.text.trim() == expectedPin) {
        Navigator.pop(context, true);
      } else {
        errorText.value = 'Incorrect PIN.';
      }
    }

    return AlertDialog(
      title: const Text('Verify Current Passcode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Current 4-Digit PIN',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => errorText.value = null,
            onSubmitted: (_) => verify(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await authenticateWithFaceId(
                  reason: 'Authenticate with Face ID to modify security settings',
                );
                if (ok && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(FluentIcons.person_passkey_24_regular),
              label: const Text('Verify with Face ID'),
            ),
          ),
          if (errorText.value != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText.value!,
              style: TextStyle(color: context.theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        const PopButton(),
        FilledButton(
          onPressed: verify,
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
