// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../../constants/db_keys.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../../../../../widgets/compact_switch.dart';
import '../../../../../auth/presentation/face_id_auth_service.dart';

part 'show_nsfw_switch.g.dart';

bool _nsfwSessionFaceIdUnlocked = false;

/// Optional override for widget tests to simulate Face ID pass/fail.
Future<bool> Function({String reason})? debugNsfwFaceIdAuthOverride;

/// Resets the in-memory Face ID unlock for NSFW content (e.g. on sign-out or tests).
void resetNsfwFaceIdSession() {
  _nsfwSessionFaceIdUnlocked = false;
}

@Riverpod(keepAlive: true)
class ShowNSFW extends _$ShowNSFW with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() {
    final saved = initialize(DBKeys.showNSFW) ?? false;
    // Never allow NSFW to be active in a new app session until unlocked with Face ID.
    if (!_nsfwSessionFaceIdUnlocked) return false;
    return saved;
  }

  @override
  void update(bool? value) {
    final enabled = value ?? false;
    _nsfwSessionFaceIdUnlocked = enabled;
    super.update(enabled);
  }
}

class ShowNSFWTile extends ConsumerWidget {
  const ShowNSFWTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(showNSFWProvider).ifNull(false);
    return CompactSwitchListTile(
      controlAffinity: ListTileControlAffinity.trailing,
      title: Text(context.l10n.nsfw),
      subtitle: const Text('Requires Face ID to unlock 18+ sources & history'),
      onChanged: (nextValue) async {
        if (!nextValue) {
          ref.read(showNSFWProvider.notifier).update(false);
          return;
        }
        final authOverride = debugNsfwFaceIdAuthOverride;
        if (authOverride != null) {
          final ok = await authOverride(
            reason: 'Authenticate with Face ID to view 18+ / NSFW content',
          );
          if (!ok) return;
          ref.read(showNSFWProvider.notifier).update(true);
          return;
        }
        if (!kIsWeb && Platform.isIOS) {
          final ok = await authenticateWithFaceId(
            reason: 'Authenticate with Face ID to view 18+ / NSFW content',
          );
          if (!ok) return;
        }
        ref.read(showNSFWProvider.notifier).update(true);
      },
      value: isEnabled,
    );
  }
}
