// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../constants/language_list.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/emoticons.dart';
import '../../../quick_open/presentation/unified_search/phone_search_view.dart';
import '../../../settings/presentation/library/widgets/persistent_search_bar/persistent_search_bar.dart';
import '../../domain/extension/top_extensions.dart';
import '../browse/browse_no_search_results.dart';
import '../browse/browse_section_grid.dart';
import '../browse/media_resource_widgets.dart';
import 'controller/source_controller.dart';
import 'widgets/source_card.dart';
import 'widgets/source_list_tile.dart';

class SourceScreen extends HookConsumerWidget {
  const SourceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceMapData = ref.watch(sourceMapFilteredAndQueriedProvider);
    final query = ref.watch(sourceSearchQueryProvider);
    final activeCategory = ref.watch(selectedResourceCategoryProvider);
    final selectedVideos = visibleCatalogForCategory(
      ref,
      ResourceCategory.videos,
      query: query,
      onlySelected: true,
    );
    final selectedComics = visibleCatalogForCategory(
      ref,
      ResourceCategory.comics,
      query: query,
      onlySelected: true,
    );
    final selectedOther = visibleCatalogForCategory(
      ref,
      ResourceCategory.other,
      query: query,
      onlySelected: true,
    );
    final showManga =
        activeCategory == ResourceCategory.all ||
        activeCategory == ResourceCategory.manga;
    final showVideos =
        (activeCategory == ResourceCategory.all ||
            activeCategory == ResourceCategory.videos) &&
        selectedVideos.isNotEmpty;
    final showComics =
        (activeCategory == ResourceCategory.all ||
            activeCategory == ResourceCategory.comics) &&
        selectedComics.isNotEmpty;
    final showOther =
        (activeCategory == ResourceCategory.all ||
            activeCategory == ResourceCategory.other) &&
        selectedOther.isNotEmpty;

    final allPinned = ref.watch(pinnedSourcesProvider);
    final pinned = query.isBlank
        ? allPinned
        : allPinned.where((s) => s.name.query(query)).toList();

    final sourceMap = {...?sourceMapData.value};
    final localSource = sourceMap.remove("localsourcelang");
    final lastUsed = sourceMap.remove("lastUsed");
    final allSource = sourceMap.remove("all");

    refresh() => ref.refresh(sourceListProvider.future);
    useEffect(() {
      // Effect bodies run during build; invalidating a provider there throws.
      if (sourceMapData.isNotLoading) {
        Future.microtask(() {
          if (context.mounted) refresh();
        });
      }
      return;
    }, []);

    useEffect(() {
      sourceMapData.showToastOnError(
        ref.read(toastProvider),
        withMicrotask: true,
      );
      return;
    }, [sourceMapData.value]);

    final body = sourceMapData.showUiWhenData(context, (data) {
      final hasVisibleManga =
          showManga &&
          (pinned.isNotEmpty ||
              localSource.isNotBlank ||
              lastUsed.isNotBlank ||
              allSource.isNotBlank ||
              sourceMap.values.any((list) => list.isNotBlank));
      final hasVisibleMedia = showVideos || showComics || showOther;
      if (!hasVisibleManga && !hasVisibleMedia) {
        if (query.isNotBlank) return const BrowseNoSearchResults();
        return Emoticons(
          title: context.l10n.noSourcesFound,
          button: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => ref
                    .read(selectedMediaResourcesProvider.notifier)
                    .selectDefaults(),
                child: const Text('Select Default Resources'),
              ),
              TextButton(
                onPressed: refresh,
                child: Text(context.l10n.refresh),
              ),
            ],
          ),
        );
      }
      if (context.usesDesktopShell) {
        return RefreshIndicator(
          onRefresh: refresh,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CustomScrollView(
              slivers: [
                if (showVideos) ...[
                  const SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: 'Videos & Anime Resources',
                      topPadding: 16,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MediaResourceSourceTile(
                        item: selectedVideos[index],
                      ),
                      childCount: selectedVideos.length,
                    ),
                  ),
                ],
                if (showComics) ...[
                  const SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: 'Comics & Graphic Novels',
                      topPadding: 16,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MediaResourceSourceTile(
                        item: selectedComics[index],
                      ),
                      childCount: selectedComics.length,
                    ),
                  ),
                ],
                if (showOther) ...[
                  const SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: 'Novels & Else Resources',
                      topPadding: 16,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MediaResourceSourceTile(
                        item: selectedOther[index],
                      ),
                      childCount: selectedOther.length,
                    ),
                  ),
                ],
                if (showManga && pinned.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: languageMap["pinned"]?.displayName ?? "",
                      topPadding: 16,
                    ),
                  ),
                  BrowseCardGrid.source(
                    itemCount: pinned.length,
                    itemBuilder: (context, index) =>
                        SourceCard(source: pinned[index]),
                  ),
                ],
                if (showManga && lastUsed.isNotBlank) ...[
                  SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: languageMap["lastUsed"]?.displayName ?? "",
                      topPadding: pinned.isEmpty ? 16 : 24,
                    ),
                  ),
                  BrowseCardGrid.source(
                    itemCount: lastUsed!.length,
                    itemBuilder: (context, index) =>
                        SourceCard(source: lastUsed[index]),
                  ),
                ],
                if (showManga && allSource.isNotBlank) ...[
                  SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: languageMap["all"]?.displayName ?? "",
                      topPadding: pinned.isEmpty && lastUsed.isBlank ? 16 : 24,
                    ),
                  ),
                  BrowseCardGrid.source(
                    itemCount: allSource!.length,
                    itemBuilder: (context, index) =>
                        SourceCard(source: allSource[index]),
                  ),
                ],
                if (showManga)
                  for (final k in sourceMap.keys) ...[
                    if (sourceMap[k].isNotBlank) ...[
                      SliverToBoxAdapter(
                        child: BrowseSectionHeading(
                          title: languageMap[k]?.displayName ?? k,
                          topPadding: 24,
                        ),
                      ),
                      BrowseCardGrid.source(
                        itemCount: sourceMap[k]!.length,
                        itemBuilder: (context, index) =>
                            SourceCard(source: sourceMap[k]![index]),
                      ),
                    ],
                  ],
                if (showManga && localSource.isNotBlank) ...[
                  SliverToBoxAdapter(
                    child: BrowseSectionHeading(
                      title: languageMap["localsourcelang"]?.displayName ?? "",
                      topPadding: 24,
                    ),
                  ),
                  BrowseCardGrid.source(
                    itemCount: localSource!.length,
                    itemBuilder: (context, index) =>
                        SourceCard(source: localSource[index]),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          slivers: [
            if (showVideos) ...[
              const SliverToBoxAdapter(
                child: ListTile(title: Text('Videos & Anime Resources')),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      MediaResourceSourceTile(item: selectedVideos[index]),
                  childCount: selectedVideos.length,
                ),
              ),
            ],
            if (showComics) ...[
              const SliverToBoxAdapter(
                child: ListTile(title: Text('Comics & Graphic Novels')),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      MediaResourceSourceTile(item: selectedComics[index]),
                  childCount: selectedComics.length,
                ),
              ),
            ],
            if (showOther) ...[
              const SliverToBoxAdapter(
                child: ListTile(title: Text('Novels & Else Resources')),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      MediaResourceSourceTile(item: selectedOther[index]),
                  childCount: selectedOther.length,
                ),
              ),
            ],
            if (showManga && pinned.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(languageMap["pinned"]?.displayName ?? ""),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => SourceListTile(source: pinned[index]),
                  childCount: pinned.length,
                ),
              ),
            ],
            if (showManga && lastUsed.isNotBlank) ...[
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(languageMap["lastUsed"]?.displayName ?? ""),
                ),
              ),
              SliverToBoxAdapter(
                child: SourceListTile(source: lastUsed!.first),
              ),
            ],
            if (showManga && allSource.isNotBlank) ...[
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(languageMap["all"]?.displayName ?? ""),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => SourceListTile(source: allSource![index]),
                  childCount: allSource?.length,
                ),
              ),
            ],
            if (showManga)
              for (final k in sourceMap.keys) ...[
                if (sourceMap[k].isNotBlank) ...[
                  SliverToBoxAdapter(
                    child: ListTile(
                      title: Text(languageMap[k]?.displayName ?? k),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          SourceListTile(source: sourceMap[k]![index]),
                      childCount: sourceMap[k]?.length,
                    ),
                  ),
                ],
              ],
            if (showManga && localSource.isNotBlank) ...[
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(
                    languageMap["localsourcelang"]?.displayName ?? "",
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SourceListTile(source: localSource!.first),
              ),
            ],
          ],
        ),
      );
    }, refresh: refresh);

    final phone = context.windowSizeClass == WindowSizeClass.compact;
    final persistentBox =
        phone && ref.watch(libraryPersistentSearchBarProvider).ifNull();
    return Column(
      children: [
        if (persistentBox)
          const PhoneSearchEntry(origin: PhoneSearchOrigin.sources, box: true),
        const ResourceCategoryFilterBar(),
        Expanded(child: body),
      ],
    );
  }
}
