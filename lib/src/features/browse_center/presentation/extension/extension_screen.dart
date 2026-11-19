// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../constants/app_sizes.dart';
import '../../../../constants/language_list.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/app_utils.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/search_field.dart';
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
            key: ValueKey('$title:${list[index].pkgName}'),
            extension: list[index],
          ),
        )
      else
        SliverList(
          key: key,
          delegate: SliverChildBuilderDelegate(
            (context, index) => ExtensionListTile(
              key: ValueKey('$title:${list[index].pkgName}'),
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
    final activeSort = ref.watch(selectedExtensionSortProvider);
    final disabledPkgs = {
      for (final p in ref.watch(disabledExtensionsProvider) ?? const <String>[])
        p.trim().toLowerCase(),
    };

    List<Extension>? filterAndSortCategory(List<Extension>? list) {
      if (list == null) return null;
      final filtered = list
          .where((e) => matchesExtensionCategory(e, activeCategory))
          .toList();
      filtered.sort((a, b) {
        switch (activeSort) {
          case ExtensionSortOption.nameAsc:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case ExtensionSortOption.nameDesc:
            return b.name.toLowerCase().compareTo(a.name.toLowerCase());
          case ExtensionSortOption.language:
            final la = normalizeExtensionLang(a);
            final lb = normalizeExtensionLang(b);
            final cmp = la.compareTo(lb);
            return cmp != 0
                ? cmp
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case ExtensionSortOption.enabledFirst:
            final aDis = disabledPkgs.contains(a.pkgName.trim().toLowerCase());
            final bDis = disabledPkgs.contains(b.pkgName.trim().toLowerCase());
            if (aDis != bDis) return aDis ? 1 : -1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
      });
      return filtered;
    }

    final rawMap = {...?extensionMapData.value};
    final installed = filterAndSortCategory(rawMap.remove("installed"));
    final update = filterAndSortCategory(rawMap.remove("update"));
    final all = filterAndSortCategory(rawMap.remove("all"));
    final extensionMap = <String, List<Extension>>{
      for (final entry in rawMap.entries)
        entry.key: filterAndSortCategory(entry.value) ?? const <Extension>[],
    };

    refresh() => ref.read(extensionActionsProvider).refreshList();

    final updatingAll = useState(false);

    useEffect(() {
      if (extensionMapData.isNotLoading) {
        Future.microtask(() async {
          if (!context.mounted) return;
          await refresh();
          if (!context.mounted) return;
          if (ref.read(autoUpdateExtensionsProvider) ?? true) {
            await ref
                .read(extensionActionsProvider)
                .autoUpdateInstalledExtensions();
          }
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

    final body = extensionMapData.showUiWhenData(
      context,
      (data) {
        final enabledLangsList = ref.watch(extensionLanguageFilterProvider);
        final enabledLangsSet = enabledLangsList != null
            ? {for (final l in enabledLangsList) l.trim().toLowerCase()}
            : null;
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
        final topNovels = query.isBlank &&
                (activeCategory == ResourceCategory.all ||
                    activeCategory == ResourceCategory.novels)
            ? selectTopNovelExtensions(
                combinedAll,
                enabledLanguages: enabledLangsSet,
              )
            : const <Extension>[];
        final top10Manga = query.isBlank &&
                (activeCategory == ResourceCategory.all ||
                    activeCategory == ResourceCategory.manga)
            ? selectTop10Extensions(
                combinedAll,
                enabledLanguages: enabledLangsSet,
              )
            : const <Extension>[];

        final hasVisible =
            installed.isNotBlank ||
            update.isNotBlank ||
            all.isNotBlank ||
            topNovels.isNotEmpty ||
            top10Manga.isNotEmpty ||
            extensionMap.values.any((list) => list.isNotBlank);

        if (!hasVisible) {
          if (query.isNotBlank) return const BrowseNoSearchResults();
          return Emoticons(
            title: context.l10n.extensionListEmpty,
            button: TextButton(
              onPressed: refresh,
              child: Text(context.l10n.refresh),
            ),
          );
        }

        final scrollView = CustomScrollView(
          slivers: [
            if (update.isNotBlank)
              ...extensionSet(
                key: const ValueKey("update"),
                title: languageMap["update"]?.displayName ?? "Updates Pending",
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
                title: languageMap["installed"]?.displayName ?? "Installed",
                extensions: installed,
                desktop: desktop,
                headerTrailing: Builder(
                  builder: (context) {
                    final disabledList =
                        ref.watch(disabledExtensionsProvider) ?? const <String>[];
                    final allEnabled = (installed ?? []).every(
                      (ext) => !disabledList.any(
                        (pkg) =>
                            pkg.trim().toLowerCase() ==
                            ext.pkgName.trim().toLowerCase(),
                      ),
                    );
                    return TextButton(
                      onPressed: () async {
                        for (final ext in installed ?? const <Extension>[]) {
                          await ref
                              .read(extensionActionsProvider)
                              .setExtensionEnabled(ext.pkgName, !allEnabled);
                        }
                      },
                      child: Text(allEnabled ? 'Disable All' : 'Enable All'),
                    );
                  },
                ),
              ),
            if (top10Manga.isNotEmpty)
              ...extensionSet(
                key: const ValueKey("top10"),
                title: 'Top 10 Popular Manga Extensions (EN & AR)',
                extensions: top10Manga,
                desktop: desktop,
              ),
            if (topNovels.isNotEmpty)
              ...extensionSet(
                key: const ValueKey("top_novels"),
                title: 'Top Novel & Book Extensions (EN & AR)',
                extensions: topNovels,
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
