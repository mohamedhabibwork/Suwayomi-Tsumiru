// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../utils/mixin/shared_preferences_client_mixin.dart';

part 'auto_scroll_controller.g.dart';

/// Session-scoped; resets to off when the reader is closed.
@riverpod
class AutoScrollActive extends _$AutoScrollActive {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void start() => state = true;

  void stop() => state = false;
}

class PageCurlTransitionNotifier extends Notifier<bool?>
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.pageCurlTransition);
}

final pageCurlTransitionProvider =
    NotifierProvider<PageCurlTransitionNotifier, bool?>(
  PageCurlTransitionNotifier.new,
);

class AutoScrollSleepTimerMinutesNotifier extends Notifier<int?>
    with SharedPreferenceClientMixin<int> {
  @override
  int? build() => initialize(DBKeys.autoScrollSleepTimerMinutes);
}

final autoScrollSleepTimerMinutesProvider =
    NotifierProvider<AutoScrollSleepTimerMinutesNotifier, int?>(
  AutoScrollSleepTimerMinutesNotifier.new,
);

class AutoScrollHoldPausedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setPaused(bool value) => state = value;
}

final autoScrollHoldPausedProvider =
    NotifierProvider<AutoScrollHoldPausedNotifier, bool>(
  AutoScrollHoldPausedNotifier.new,
);

final autoScrollEffectiveActiveProvider = Provider<bool>((ref) {
  final active = ref.watch(autoScrollActiveProvider);
  final holdPaused = ref.watch(autoScrollHoldPausedProvider);
  return active && !holdPaused;
});

class AutoScrollRemainingSecondsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void startCountdown(int seconds) {
    state = seconds > 0 ? seconds : 0;
  }

  void tick() {
    if (state <= 0) return;
    final next = state - 1;
    state = next;
    if (next <= 0) {
      ref.read(autoScrollActiveProvider.notifier).stop();
    }
  }

  void clear() {
    state = 0;
  }
}

final autoScrollRemainingSecondsProvider =
    NotifierProvider<AutoScrollRemainingSecondsNotifier, int>(
  AutoScrollRemainingSecondsNotifier.new,
);

