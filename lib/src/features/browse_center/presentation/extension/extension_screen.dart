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
    final activeCategory = ref.watch(selectedResourceCategoryProvider);

    List<Extension>? filterCategory(List<Extension>? list) => list
        ?.where((e) => matchesExtensionCategory(e, activeCategory))
        .toList();

    final rawMap = {...?extensionMapData.value};
    final installed = filterCategory(rawMap.remove("installed"));
    final update = filterCategory(rawMap.remove("update"));
    final all = filterCategory(rawMap.remove("all"));
    final extensionMap = <String, List<Extension>>{
      for (final entry in rawMap.entries)
        entry.key: filterCategory(entry.value) ?? const <Extension>[],
    };

    refresh() => ref.read(extensionActionsProvider).refreshList();

    final updatingAll = useState(false);

    useEffect(() {
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
    final desktop = context.usesDesktopShell;
    final canManageStores = ref
        .watch(settledAccountAccessProvider)
        .allows(Enum$UserPermission.MANAGE_EXTENSION_STORES);
    final storeList = ref.watch(extensionStoreListProvider);
    final existingStoreUrls = {
      ...?storeList.value?.stores.map((s) => s.indexUrl),
    };
    final hasDefaultStores = kCuratedExtensionStores
        .where((s) => s.isDefault && !s.isNsfw)
        .every((s) => existingStoreUrls.contains(s.indexUrl));
    final addingStores = useState(false);

    Future<void> quickAddDefaultStores() async {
      if (addingStores.value) return;
      addingStores.value = true;
      await AppUtils.guard(() async {
        for (final preset in kCuratedExtensionStores.where(
          (s) => s.isDefault && !s.isNsfw,
        )) {
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
      if (context.mounted) addingStores.value = false;
    }

    final body = extensionMapData.showUiWhenData(
      context,
      (data) {
        final combinedAll = <Extension>[
          ...?extensionMapData.value?["installed"],
          ...?extensionMapData.value?["update"],
          ...?extensionMapData.value?["all"],
          for (final entry in (extensionMapData.value ?? {}).entries)
            if (entry.key != "installed" &&
                entry.key != "update" &&
                entry.key != "all")
              ...entry.value,
        ];
        final topVideos = query.isBlank &&
                (activeCategory == ResourceCategory.all ||
                    activeCategory == ResourceCategory.videos)
            ? selectTopVideoExtensions(combinedAll)
            : const <Extension>[];
        final top10Manga = query.isBlank &&
                (activeCategory == ResourceCategory.all ||
                    activeCategory == ResourceCategory.manga)
            ? selectTop10Extensions(combinedAll)
            : const <Extension>[];

        final hasVisible =
            installed.isNotBlank ||
            update.isNotBlank ||
            all.isNotBlank ||
            topVideos.isNotEmpty ||
            top10Manga.isNotEmpty ||
            extensionMap.values.any((list) => list.isNotBlank);

        if (!hasVisible) {
          if (query.isNotBlank) return const BrowseNoSearchResults();
          return Emoticons(
            title: context.l10n.extensionListEmpty,
            button: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canManageStores && !hasDefaultStores)
                  FilledButton.icon(
                    onPressed:
                        addingStores.value ? null : quickAddDefaultStores,
                    icon: const Icon(FluentIcons.star_24_regular),
                    label: Text(
                      addingStores.value
                          ? context.l10n.processing
                          : 'Add All Default Stores (Manga, Video, Aidoku & Mangayomi)',
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
            if (query.isBlank && canManageStores && !hasDefaultStores)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(FluentIcons.star_24_regular),
                      title: const Text(
                        'Add All Default Stores (Manga, Videos, Aidoku & Mangayomi)',
                      ),
                      subtitle: const Text(
                        'Keiyoushi, Yuzono Anime, MO350AZ No-NSFW, FelipeGFA, Aidoku & Mangayomi',
                      ),
                      trailing: FilledButton(
                        onPressed:
                            addingStores.value ? null : quickAddDefaultStores,
                        child: Text(
                          addingStores.value
                              ? context.l10n.processing
                              : context.l10n.add,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (topVideos.isNotEmpty)
              ...extensionSet(
                key: const ValueKey("top_videos"),
                title: 'Top Video & Anime Extensions',
                extensions: topVideos,
                desktop: desktop,
                headerTrailing: TextButton(
                  onPressed: () async {
                    final toInstall = topVideos
                        .where((e) => !e.isInstalled)
                        .take(4)
                        .map((e) => e.pkgName)
                        .toList();
                    for (final pkg in toInstall) {
                      try {
                        await ref.read(extensionActionsProvider).install(pkg);
                      } catch (_) {}
                    }
                  },
                  child: const Text('Install Video Defaults'),
                ),
              ),
            if (top10Manga.isNotEmpty)
              ...extensionSet(
                key: const ValueKey("top10"),
                title: 'Top 10 Popular Manga Extensions',
                extensions: top10Manga,
                desktop: desktop,
                headerTrailing: TextButton(
                  onPressed: () async {
                    final toInstall = top10Manga
                        .where((e) => !e.isInstalled)
                        .take(4)
                        .map((e) => e.pkgName)
                        .toList();
                    for (final pkg in toInstall) {
                      try {
                        await ref.read(extensionActionsProvider).install(pkg);
                      } catch (_) {}
                    }
                  },
                  child: const Text('Install Defaults'),
                ),
              ),
            if (update.isNotBlank)
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
            if (installed.isNotBlank)
              ...extensionSet(
                key: const ValueKey("installed"),
                title: languageMap["installed"]?.displayName ?? "",
                extensions: installed,
                desktop: desktop,
              ),
            if (all.isNotBlank)
              ...extensionSet(
                key: const ValueKey("all"),
                title: languageMap["all"]?.displayName ?? "",
                extensions: all,
                desktop: desktop,
              ),
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
