import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tsumiru/src/features/manga_book/presentation/reader/controller/auto_scroll_controller.dart';

void main() {
  group('AutoScroll Hold-to-Pause & Sleep Timer', () {
    test('autoScrollHoldPausedProvider pauses effective auto-scroll without clearing active state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(autoScrollActiveProvider.notifier).start();
      expect(container.read(autoScrollActiveProvider), isTrue);
      expect(container.read(autoScrollEffectiveActiveProvider), isTrue);

      container.read(autoScrollHoldPausedProvider.notifier).setPaused(true);
      expect(container.read(autoScrollActiveProvider), isTrue);
      expect(container.read(autoScrollEffectiveActiveProvider), isFalse);

      container.read(autoScrollHoldPausedProvider.notifier).setPaused(false);
      expect(container.read(autoScrollEffectiveActiveProvider), isTrue);
    });

    test('sleep timer countdown stops autoScrollActiveProvider when reaching 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(autoScrollActiveProvider.notifier).start();
      container.read(autoScrollRemainingSecondsProvider.notifier).startCountdown(2);
      expect(container.read(autoScrollRemainingSecondsProvider), 2);

      container.read(autoScrollRemainingSecondsProvider.notifier).tick();
      expect(container.read(autoScrollRemainingSecondsProvider), 1);
      expect(container.read(autoScrollActiveProvider), isTrue);

      container.read(autoScrollRemainingSecondsProvider.notifier).tick();
      expect(container.read(autoScrollRemainingSecondsProvider), 0);
      expect(container.read(autoScrollActiveProvider), isFalse);
    });
  });
}
