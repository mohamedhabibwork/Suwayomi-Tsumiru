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
        await ref
            .read(extensionStoreRepositoryProvider)
            .addStore(kKeiyoushiStoreUrl);
        if (!context.mounted) return;
        // ignore: unused_result
        ref.refresh(extensionStoreListProvider.future);
        await refresh();
      }, ref.read(toastProvider));
      if (context.mounted) addingKeiyoushi.value = false;
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
        final hasVisible =
            installed.isNotBlank ||
            update.isNotBlank ||
            all.isNotBlank ||
            extensionMap.values.any((list) => list.isNotBlank);
        if (!hasVisible) {
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
                          : 'Add Top 10 Extensions (Keiyoushi)',
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
            if (query.isBlank &&
                top10.isEmpty &&
                canManageStores &&
                !hasKeiyoushiStore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(FluentIcons.star_24_regular),
                      title: const Text('Easy Add Top 10 Extensions'),
                      subtitle: const Text(
                        'Add Keiyoushi store for MangaDex, Comick, Weeb Central, MangaFire, Bato.to & more',
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
            if (top10.isNotEmpty)
              ...extensionSet(
                key: const ValueKey("top10"),
                title: 'Top 10 Popular Extensions',
                extensions: top10,
                desktop: desktop,
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
        Expanded(child: body),
      ],
    );
  }
}
