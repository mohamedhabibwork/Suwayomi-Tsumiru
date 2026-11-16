// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/motion/reduce_motion.dart';
import '../../../../widgets/compact_switch.dart';
import '../../../../widgets/popup_widgets/pop_button.dart';
import 'security_settings_provider.dart';

Future<void> showSecuritySettingsDialog(BuildContext context) => showDialog<void>(
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

    Future<String?> promptNewPin() async {
      final controller = TextEditingController();
      return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Set 4-Digit Passcode'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: '4-Digit PIN',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            const PopButton(),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.length == 4 && int.tryParse(text) != null) {
                  Navigator.pop(ctx, text);
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
    }

    Future<void> toggleAppLock(bool value) async {
      if (value && pin.length != 4) {
        final newPin = await promptNewPin();
        if (newPin == null || newPin.length != 4) return;
        ref.read(appLockPinProvider.notifier).update(newPin);
      }
      ref.read(appLockEnabledProvider.notifier).update(value);
      ref.read(appLockSessionUnlockedProvider.notifier).setUnlocked(true);
    }

    return AlertDialog(
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
                'Require a 4-digit PIN when opening or resuming Mangaka',
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
                  value: const {0, 60, 300, 900}.contains(timeout) ? timeout : 0,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Immediately')),
                    DropdownMenuItem(value: 60, child: Text('After 1 min')),
                    DropdownMenuItem(value: 300, child: Text('After 5 min')),
                    DropdownMenuItem(value: 900, child: Text('After 15 min')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(appLockTimeoutSecondsProvider.notifier).update(v);
                    }
                  },
                ),
              ),
            ],
            const Divider(),
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
          ],
        ),
      ),
      actions: const [PopButton()],
    );
  }
}
