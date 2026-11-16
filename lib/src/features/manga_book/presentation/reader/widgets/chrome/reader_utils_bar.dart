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

import '../../../../../../constants/db_keys.dart';
import '../../../../../../constants/enum.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/motion/reduce_motion.dart';
import '../../../../../../utils/theme/brand.dart';
import '../../../../../../widgets/compact_switch.dart';
import '../../../../../settings/presentation/reader/widgets/reader_webtoon_prefs/reader_webtoon_prefs.dart';
import '../../controller/auto_scroll_controller.dart';

class ReaderUtilsBar extends HookConsumerWidget {
  const ReaderUtilsBar({
    super.key,
    required this.expanded,
    required this.readerMode,
  });

  /// Owned by [ReaderWrapper]; flipped by this bar's own chevron handle.
  final ValueNotifier<bool> expanded;

  /// Resolved reading mode, used to pick scroll-vs-advance wording, interval,
  /// and whether the smooth/jump option is meaningful.
  final ReaderMode readerMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.theme.colorScheme;
    final active = ref.watch(autoScrollActiveProvider);
    final holdPaused = ref.watch(autoScrollHoldPausedProvider);
    final sleepMinutes =
        ref.watch(autoScrollSleepTimerMinutesProvider) ??
        DBKeys.autoScrollSleepTimerMinutes.initial as int;
    final remainingSeconds = ref.watch(autoScrollRemainingSecondsProvider);

    useEffect(() {
      if (!active) return null;
      if (sleepMinutes > 0 && ref.read(autoScrollRemainingSecondsProvider) <= 0) {
        Future.microtask(() {
          ref
              .read(autoScrollRemainingSecondsProvider.notifier)
              .startCountdown(sleepMinutes * 60);
        });
      }
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (ref.read(autoScrollRemainingSecondsProvider) > 0) {
          ref.read(autoScrollRemainingSecondsProvider.notifier).tick();
        }
      });
      return timer.cancel;
    }, [active, sleepMinutes]);

    // Scroll and page advance share a toggle but retain separate intervals.
    final isScrollMode =
        readerMode == ReaderMode.webtoon ||
        readerMode == ReaderMode.continuousVertical;

    final int interval;
    if (isScrollMode) {
      interval =
          ref.watch(autoScrollIntervalSecondsProvider) ??
          DBKeys.autoScrollIntervalSeconds.initial as int;
    } else {
      interval =
          ref.watch(autoAdvanceIntervalSecondsProvider) ??
          DBKeys.autoAdvanceIntervalSeconds.initial as int;
    }

    void setInterval(int value) {
      final clamped = value.clamp(1, 30);
      if (isScrollMode) {
        ref.read(autoScrollIntervalSecondsProvider.notifier).update(clamped);
      } else {
        ref.read(autoAdvanceIntervalSecondsProvider.notifier).update(clamped);
      }
    }

    final label = isScrollMode
        ? context.l10n.autoScroll
        : context.l10n.autoAdvance;

    String formatRemaining(int sec) {
      final m = sec ~/ 60;
      final s = sec % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return Material(
      color: readerNavSurface(cs),
      child: ValueListenableBuilder<bool>(
        valueListenable: expanded,
        builder: (context, isOpen, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: context.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              alignment: Alignment.topCenter,
              child: !isOpen
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          CompactSwitch(
                            value: active,
                            activeThumbColor: cs.primary,
                            onChanged: (_) => ref
                                .read(autoScrollActiveProvider.notifier)
                                .toggle(),
                          ),
                          Expanded(
                            child: Text(
                              holdPaused && active ? '$label (Hold Paused)' : label,
                              style: TextStyle(color: cs.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<int>(
                            tooltip: 'Sleep Timer',
                            onSelected: (minutes) {
                              ref
                                  .read(autoScrollSleepTimerMinutesProvider.notifier)
                                  .update(minutes);
                              if (minutes > 0) {
                                ref
                                    .read(autoScrollRemainingSecondsProvider.notifier)
                                    .startCountdown(minutes * 60);
                              } else {
                                ref
                                    .read(autoScrollRemainingSecondsProvider.notifier)
                                    .clear();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 0, child: Text('Sleep: Off')),
                              PopupMenuItem(value: 5, child: Text('5 min')),
                              PopupMenuItem(value: 15, child: Text('15 min')),
                              PopupMenuItem(value: 30, child: Text('30 min')),
                              PopupMenuItem(value: 60, child: Text('60 min')),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FluentIcons.timer_24_regular,
                                    size: 18,
                                    color: sleepMinutes > 0 ? cs.primary : cs.onSurface,
                                  ),
                                  if (sleepMinutes > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      active && remainingSeconds > 0
                                          ? formatRemaining(remainingSeconds)
                                          : '${sleepMinutes}m',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Faster = shorter interval, so "-" lowers seconds.
                          IconButton(
                            icon: Icon(FluentIcons.subtract_24_regular, color: cs.onSurface),
                            onPressed: () => setInterval(interval - 1),
                          ),
                          Text(
                            context.l10n.autoScrollSeconds(interval),
                            style: TextStyle(color: cs.onSurface),
                          ),
                          IconButton(
                            icon: Icon(FluentIcons.add_24_regular, color: cs.onSurface),
                            onPressed: () => setInterval(interval + 1),
                          ),
                        ],
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 26,
                  visualDensity: VisualDensity.compact,
                  tooltip: label,
                  onPressed: () => expanded.value = !expanded.value,
                  icon: Icon(
                    isOpen
                        ? FluentIcons.chevron_up_24_regular
                        : FluentIcons.chevron_down_24_regular,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
