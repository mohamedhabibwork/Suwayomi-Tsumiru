// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/db_keys.dart';
import '../../../../utils/mixin/shared_preferences_client_mixin.dart';

/// Computes exponential cooldown seconds after consecutive failed PIN attempts.
/// < 3 attempts: 0s; 3: 5s; 4: 15s; 5: 30s; >= 6: 60s.
int computeLockCooldownSeconds(int failedAttempts) {
  if (failedAttempts < 3) return 0;
  if (failedAttempts == 3) return 5;
  if (failedAttempts == 4) return 15;
  if (failedAttempts == 5) return 30;
  return 60;
}

class AppLockEnabledNotifier extends Notifier<bool?>
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.appLockEnabled);
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabledNotifier, bool?>(
      AppLockEnabledNotifier.new,
    );

class AppLockPinNotifier extends Notifier<String?>
    with SharedPreferenceClientMixin<String> {
  @override
  String? build() => initialize(DBKeys.appLockPin);
}

final appLockPinProvider = NotifierProvider<AppLockPinNotifier, String?>(
  AppLockPinNotifier.new,
);

class AppLockTimeoutSecondsNotifier extends Notifier<int?>
    with SharedPreferenceClientMixin<int> {
  @override
  int? build() => initialize(DBKeys.appLockTimeoutSeconds);
}

final appLockTimeoutSecondsProvider =
    NotifierProvider<AppLockTimeoutSecondsNotifier, int?>(
      AppLockTimeoutSecondsNotifier.new,
    );

class AppLockFailedAttemptsNotifier extends Notifier<int?>
    with SharedPreferenceClientMixin<int> {
  @override
  int? build() => initialize(DBKeys.appLockFailedAttempts);
}

final appLockFailedAttemptsProvider =
    NotifierProvider<AppLockFailedAttemptsNotifier, int?>(
      AppLockFailedAttemptsNotifier.new,
    );

class AppLockCooldownUntilMsNotifier extends Notifier<int?>
    with SharedPreferenceClientMixin<int> {
  @override
  int? build() => initialize(DBKeys.appLockCooldownUntilMs);
}

final appLockCooldownUntilMsProvider =
    NotifierProvider<AppLockCooldownUntilMsNotifier, int?>(
      AppLockCooldownUntilMsNotifier.new,
    );

class DisableContentSharingNotifier extends Notifier<bool?>
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.disableContentSharing);
}

final disableContentSharingProvider =
    NotifierProvider<DisableContentSharingNotifier, bool?>(
      DisableContentSharingNotifier.new,
    );

/// Session-scoped unlock flag; starts false when appLockEnabled is true.
class AppLockSessionUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setUnlocked(bool value) => state = value;
}

final appLockSessionUnlockedProvider =
    NotifierProvider<AppLockSessionUnlockedNotifier, bool>(
      AppLockSessionUnlockedNotifier.new,
    );
