// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../constants/app_sizes.dart';
import '../../../../constants/language_list.dart';
import '../../../../graphql/__generated__/schema.graphql.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/app_utils.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/search_field.dart';
import '../../../account/data/account_providers.dart';
import '../../data/extension_store_repository/extension_store_repository.dart';
import '../../domain/extension/extension_model.dart';
import '../../domain/extension/top_extensions.dart';
import '../browse/browse_no_search_results.dart';
import '../browse/browse_section_grid.dart';
import '../browse/media_resource_widgets.dart';
import 'controller/extension_actions.dart';
import 'controller/extension_controller.dart';
import 'widgets/extension_card.dart';
import 'widgets/extension_list_tile.dart';

class ExtensionScreen extends HookConsumerWidget {
  const ExtensionScreen({super.key});

  List<Widget> extensionSet({
    Key? key,
    required String title,
    required List<Extension>? extensions,
    Widget? headerTrailing,
    bool desktop = false,
  }) {
    final list = extensions ?? const [];
    if (list.isEmpty) return <Widget>[];
    return [
      SliverToBoxAdapter(
        child: desktop
            ? BrowseSectionHeading(
                title: title,
                count: list.length,
                trailing: headerTrailing,
              )
            : ListTile(title: Text(title), trailing: headerTrailing),
      ),
      if (desktop)
        BrowseCardGrid(
          key: key,
          itemCount: list.length,
          itemBuilder: (context, index) => ExtensionCard(
            key: ValueKey(list[index].pkgName),
            extension: list[index],
          ),
        )
      else
        SliverList(
          key: key,
          delegate: SliverChildBuilderDelegate(
            (context, index) => ExtensionListTile(
              key: ValueKey(list[index].pkgName),
              extension: list[index],
            ),
            childCount: list.length,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extensionMapData = ref.watch(extensionMapFilteredAndQueriedProvider);

    final extensionMap = {...?extensionMapData.value};
    final installed = extensionMap.remove("installed");
    final update = extensionMap.remove("update");
    final all = extensionMap.remove("all");

    refresh() => ref.read(extensionActionsProvider).refreshList();

    final updatingAll = useState(false);

    useEffect(() {
      // Effect bodies run during build; invalidating a provider there throws.
      if (extensionMapData.isNotLoading) {
        Future.microtask(() {
          if (context.mounted) refresh();
        });
      }
      return;
    }, []);

    useEffect(() {
      final toast = ref.read(toastProvider);
      if (toast != null) {
        extensionMapData.showToastOnError(toast, withMicrotask: true);
      }
      return;
    }, [extensionMapData.value]);

    final query = ref.watch(extensionQueryProvider);
    final activeCategory = ref.watch(selectedResourceCategoryProvider);
    final videoResources = visibleCatalogForCategory(
      ref,
      ResourceCategory.videos,
      query: query,
    );
    final comicResources = visibleCatalogForCategory(
      ref,
      ResourceCategory.comics,
      query: query,
    );
    final otherResources = visibleCatalogForCategory(
      ref,
      ResourceCategory.other,
      query: query,
    );
    final showMangaSection =
        activeCategory == ResourceCategory.all ||
        activeCategory == ResourceCategory.manga;
    final showVideosSection =
        activeCategory == ResourceCategory.all ||
        activeCategory == ResourceCategory.videos;
    final showComicsSection =
        activeCategory == ResourceCategory.all ||
        activeCategory == ResourceCategory.comics;
    final showOtherSection =
        activeCategory == ResourceCategory.all ||
        activeCategory == ResourceCategory.other;

    final desktop = context.usesDesktopShell;
    final canManageStores = ref
        .watch(settledAccountAccessProvider)
        .allows(Enum$UserPermission.MANAGE_EXTENSION_STORES);
    final storeList = ref.watch(extensionStoreListProvider);
    final hasKeiyoushiStore =
        storeList.value?.stores.any((s) => s.indexUrl == kKeiyoushiStoreUrl) ??
        false;
    final addingKeiyoushi = useState(false);

    Future<void> quickAddKeiyoushi() async {
      if (addingKeiyoushi.value) return;
      addingKeiyoushi.value = true;
      await AppUtils.guard(() async {
        for (final preset in kCuratedExtensionStores.where((s) => s.isDefault)) {
          try {
            await ref
                .read(extensionStoreRepositoryProvider)
                .addStore(preset.indexUrl);
          } catch (_) {}
        }
        if (!context.mounted) return;
        // ignore: unused_result
        ref.refresh(extensionStoreListProvider.future);
        await refresh();
      }, ref.read(toastProvider));
      if (context.mounted) addingKeiyoushi.value = false;
    }

    List<Widget> mediaResourceSection({
      required String keyName,
      required String title,
      required List<MediaResourceItem> items,
    }) {
      if (items.isEmpty) return const <Widget>[];
      return [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: TextButton(
              onPressed: () => ref
                  .read(selectedMediaResourcesProvider.notifier)
                  .selectDefaults(),
              child: const Text('Reset Defaults'),
            ),
          ),
        ),
        SliverList(
          key: ValueKey(keyName),
          delegate: SliverChildBuilderDelegate(
            (context, index) => MediaResourceExtensionTile(
              key: ValueKey(items[index].id),
              item: items[index],
            ),
            childCount: items.length,
          ),
        ),
      ];
    }

    final body = extensionMapData.showUiWhenData(
      context,
      (data) {
        final combined = <Extension>[
          ...?installed,
          ...?update,
          ...?all,
          for (final list in extensionMap.values) ...list,
        ];
        final top10 = query.isBlank
            ? selectTop10Extensions(combined)
            : const <Extension>[];
        final hasVisibleManga =
            showMangaSection &&
            (installed.isNotBlank ||
                update.isNotBlank ||
                all.isNotBlank ||
                extensionMap.values.any((list) => list.isNotBlank));
        final hasVisibleMedia =
            (showVideosSection && videoResources.isNotEmpty) ||
            (showComicsSection && comicResources.isNotEmpty) ||
            (showOtherSection && otherResources.isNotEmpty);
        if (!hasVisibleManga && !hasVisibleMedia) {
          if (query.isNotBlank) return const BrowseNoSearchResults();
          return Emoticons(
            title: context.l10n.extensionListEmpty,
            button: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canManageStores && !hasKeiyoushiStore)
                  FilledButton.icon(
                    onPressed: addingKeiyoushi.value ? null : quickAddKeiyoushi,
                    icon: const Icon(FluentIcons.star_24_regular),
                    label: Text(
                      addingKeiyoushi.value
                          ? context.l10n.processing
                          : 'Add Default Extension Stores',
                    ),
                  ),
                TextButton(
                  onPressed: refresh,
                  child: Text(context.l10n.refresh),
                ),
              ],
            ),
          );
        }
        final scrollView = CustomScrollView(
          slivers: [
            if (showVideosSection)
              ...mediaResourceSection(
                keyName: 'videos_resources',
                title: 'Videos & Anime Extensions',
                items: videoResources,
              ),
            if (showComicsSection)
              ...mediaResourceSection(
                keyName: 'comics_resources',
                title: 'Comics & Graphic Novels Extensions',
                items: comicResources,
              ),
            if (showOtherSection)
              ...mediaResourceSection(
                keyName: 'other_resources',
                title: 'Novels & Else Resources',
                items: otherResources,
              ),
            if (showMangaSection &&
                query.isBlank &&
                top10.isEmpty &&
                canManageStores &&
                !hasKeiyoushiStore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(FluentIcons.star_24_regular),
                      title: const Text('Easy Add Default Manga & Comic Stores'),
                      subtitle: const Text(
                        'Add Keiyoushi & Yuzono stores for MangaDex, Comick, Weeb Central, MangaFire, Bato.to & more',
                      ),
                      trailing: FilledButton(
                        onPressed:
                            addingKeiyoushi.value ? null : quickAddKeiyoushi,
                        child: Text(
                          addingKeiyoushi.value
                              ? context.l10n.processing
                              : context.l10n.add,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showMangaSection && top10.isNotEmpty)
              ...extensionSet(
                key: const ValueKey("top10"),
                title: 'Top 10 Popular Manga Extensions',
                extensions: top10,
                desktop: desktop,
                headerTrailing: TextButton(
                  onPressed: () async {
                    final toInstall = top10
                        .where((e) => !(e.isInstalled ?? false))
                        .take(4)
                        .map((e) => e.pkgName)
                        .toList();
                    for (final pkg in toInstall) {
                      try {
                        await ref
                            .read(extensionActionsProvider)
                            .install(pkg);
                      } catch (_) {}
                    }
                  },
                  child: const Text('Install Defaults'),
                ),
              ),
            if (showMangaSection && update.isNotBlank)
              ...extensionSet(
                key: const ValueKey("update"),
                title: languageMap["update"]?.displayName ?? "",
                extensions: update,
                desktop: desktop,
                headerTrailing: TextButton(
                  onPressed: updatingAll.value
                      ? null
                      : () async {
                          updatingAll.value = true;
                          await AppUtils.guard(
                            () => ref
                                .read(extensionActionsProvider)
                                .updateAll([
                                  for (final e in update ?? []) e.pkgName,
                                ]),
                            ref.read(toastProvider),
                          );
                          if (context.mounted) updatingAll.value = false;
                        },
                  child: Text(context.l10n.updateAll),
                ),
              ),
            if (showMangaSection && installed.isNotBlank)
              ...extensionSet(
                key: const ValueKey("installed"),
                title: languageMap["installed"]?.displayName ?? "",
                extensions: installed,
                desktop: desktop,
              ),
            if (showMangaSection && all.isNotBlank)
              ...extensionSet(
                key: const ValueKey("all"),
                title: languageMap["all"]?.displayName ?? "",
                extensions: all,
                desktop: desktop,
              ),
            if (showMangaSection)
              for (final k in extensionMap.keys)
                if (extensionMap[k].isNotBlank)
                  ...extensionSet(
                    key: ValueKey(k),
                    title: languageMap[k]?.displayName ?? k,
                    extensions: extensionMap[k],
                    desktop: desktop,
                  ),
          ],
        );
        return RefreshIndicator(
          onRefresh: refresh,
          child: desktop
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: scrollView,
                )
              : scrollView,
        );
      },
      refresh: refresh,
    );

    return Column(
      children: [
        if (!context.usesDesktopShell)
          SizedBox(
            width: context.windowSizeClass >= WindowSizeClass.expanded
                ? context.widthScale(scale: .5)
                : null,
            child: Padding(
              padding: KEdgeInsets.h16v4.size,
              child: SearchField(
                autofocus: false,
                labelText: context.l10n.searchForExtensions,
                initialText: ref.watch(extensionQueryProvider),
                onChanged: (val) =>
                    ref.read(extensionQueryProvider.notifier).update(val),
              ),
            ),
          ),
        const ResourceCategoryFilterBar(),
        Expanded(child: body),
      ],
    );
  }
}
