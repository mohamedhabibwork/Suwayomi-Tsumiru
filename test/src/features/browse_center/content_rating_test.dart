// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/features/browse_center/domain/content_rating.dart';
import 'package:tsumiru/src/features/history/data/graphql/__generated__/query.graphql.dart';
import 'package:tsumiru/src/features/history/presentation/history_controller.dart';
import 'package:tsumiru/src/features/settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/graphql/__generated__/schema.graphql.dart';
import 'package:tsumiru/src/l10n/generated/app_localizations.dart';
import 'package:tsumiru/src/widgets/compact_switch.dart';

Fragment$HistoryChapterDto _historyItem({
  required int id,
  required String title,
  List<String> genre = const [],
  Enum$ContentWarning warning = Enum$ContentWarning.SAFE,
}) {
  return Fragment$HistoryChapterDto(
    id: id,
    mangaId: id,
    name: 'Chapter 1',
    chapterNumber: 1,
    fetchedAt: '1700000000',
    uploadDate: '1700000000',
    pageCount: 10,
    sourceOrder: 1,
    url: '/c/$id',
    meta: const [],
    user: Fragment$HistoryChapterDto$user(
      isBookmarked: false,
      isDownloaded: false,
      isRead: true,
      lastPageRead: 10,
      lastReadAt: '1700000000',
    ),
    manga: Fragment$HistoryChapterDto$manga(
      id: id,
      title: title,
      genre: genre,
      sourceId: '1',
      source: Fragment$HistoryChapterDto$manga$source(
        id: '1',
        contentWarning: warning,
      ),
      meta: const [],
      user: Fragment$HistoryChapterDto$manga$user(
        inLibrary: true,
        unreadCount: 0,
      ),
    ),
  );
}

void main() {
  tearDown(() {
    debugNsfwFaceIdAuthOverride = null;
    resetNsfwFaceIdSession();
  });

  test('adult tags match whole tags case-insensitively, no false positives', () {
    expect(hasAdultTag(['Adult']), true);
    expect(hasAdultTag(['Ecchi', 'SMUT']), true);
    expect(hasAdultTag([' 18+ ']), true);

    // "Mature" marks dark themes on aggregators, not adult content — it was
    // flagging ordinary action manhwa. And whole-tag matching keeps compound
    // tags like "Young Adult" from tripping "adult".
    expect(hasAdultTag(['Mature']), false);
    expect(hasAdultTag(['Young Adult']), false);
    expect(hasAdultTag(['Action', 'Romance', 'Drama']), false);
    expect(hasAdultTag(const []), false);
  });

  test('showNSFW defaults to false and stays locked until Face ID unlocks session', () async {
    resetNsfwFaceIdSession();
    SharedPreferences.setMockInitialValues({DBKeys.showNSFW.name: true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(DBKeys.showNSFW.initial, false);
    expect(container.read(showNSFWProvider), false);
  });

  testWidgets('ShowNSFWTile requires Face ID before enabling NSFW', (tester) async {
    resetNsfwFaceIdSession();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ShowNSFWTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reject Face ID -> stays false
    debugNsfwFaceIdAuthOverride = ({String reason = ''}) async => false;
    final tileSwitch = tester.widget<CompactSwitchListTile>(
      find.byType(CompactSwitchListTile),
    );
    tileSwitch.onChanged!(true);
    await tester.pumpAndSettle();
    expect(container.read(showNSFWProvider), false);

    // Pass Face ID -> enables NSFW
    debugNsfwFaceIdAuthOverride = ({String reason = ''}) async => true;
    tileSwitch.onChanged!(true);
    await tester.pumpAndSettle();
    expect(container.read(showNSFWProvider), true);
  });

  test('isHistoryItemNsfw detects NSFW sources and 18+ genres', () {
    final safeItem = _historyItem(
      id: 1,
      title: 'Safe Series',
      genre: const ['Action', 'Adventure'],
      warning: Enum$ContentWarning.SAFE,
    );
    final nsfwSourceItem = _historyItem(
      id: 2,
      title: 'NSFW Source Series',
      genre: const ['Romance'],
      warning: Enum$ContentWarning.NSFW,
    );
    final adultGenreItem = _historyItem(
      id: 3,
      title: '18+ Tagged Series',
      genre: const ['Drama', '18+'],
      warning: Enum$ContentWarning.SAFE,
    );

    expect(isHistoryItemNsfw(safeItem), false);
    expect(isHistoryItemNsfw(nsfwSourceItem), true);
    expect(isHistoryItemNsfw(adultGenreItem), true);
  });
}
