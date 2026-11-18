// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../data/extension_store_repository/extension_store_repository.dart';
import '../../domain/extension/top_extensions.dart';
import '../extension/controller/extension_actions.dart';
import '../extension/controller/extension_controller.dart';
import '../source/controller/source_controller.dart';

IconData iconForResourceCategory(ResourceCategory category) =>
    switch (category) {
      ResourceCategory.videos => FluentIcons.video_24_regular,
      ResourceCategory.novels => FluentIcons.book_letter_24_regular,
      ResourceCategory.comics => FluentIcons.book_open_24_regular,
      ResourceCategory.other => FluentIcons.library_24_regular,
      ResourceCategory.manga => FluentIcons.book_24_regular,
      ResourceCategory.all => FluentIcons.apps_24_regular,
    };

class ResourceCategoryFilterBar extends ConsumerWidget {
  const ResourceCategoryFilterBar({
    super.key,
    this.onSelectDefaults,
  });

  final VoidCallback? onSelectDefaults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCategory = ref.watch(selectedResourceCategoryProvider);
    final showNsfw = ref.watch(showNSFWProvider).ifNull(false);
    final onlyNsfw = showNsfw && ref.watch(onlyNsfwModeProvider).ifNull(false);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        spacing: 8,
        children: [
          for (final category in ResourceCategory.values)
            FilterChip(
              selected: activeCategory == category,
              avatar: Icon(iconForResourceCategory(category), size: 16),
              label: Text(category.label),
              onSelected: (_) => ref
                  .read(selectedResourceCategoryProvider.notifier)
                  .select(category),
            ),
          FilterChip(
            selected: showNsfw,
            avatar: Icon(
              showNsfw
                  ? FluentIcons.shield_24_filled
                  : FluentIcons.shield_lock_24_regular,
              size: 16,
            ),
            label: const Text('+18'),
            onSelected: (v) => setNsfwEnabled(ref, v),
          ),
          FilterChip(
            selected: onlyNsfw,
            avatar: const Icon(FluentIcons.fire_24_regular, size: 16),
            label: const Text('Only +18'),
            onSelected: (v) => setOnlyNsfwMode(ref, v),
          ),
          ActionChip(
            avatar: const Icon(
              FluentIcons.checkmark_circle_24_regular,
              size: 16,
            ),
            label: const Text('Install Defaults'),
            onPressed: () async {
              final toast = ref.read(toastProvider);
              toast?.show(
                'Syncing default Manga, Video, Novel, Aidoku & Mangayomi stores...',
              );
              final storeList = await ref.read(extensionStoreListProvider.future);
              final existingUrls = {
                ...?storeList?.stores.map((s) => s.indexUrl),
              };
              for (final preset in kCuratedExtensionStores.where(
                (s) => s.isDefault && !s.isNsfw,
              )) {
                if (isExtensionStoreUrlPresent(preset.indexUrl, existingUrls)) {
                  continue;
                }
                try {
                  await ref
                      .read(extensionStoreRepositoryProvider)
                      .addStore(preset.indexUrl);
                } catch (_) {}
              }
              await ref.read(extensionActionsProvider).refreshList();
              final extList = await ref.read(extensionProvider.future);
              if (extList != null) {
                final topManga = selectTop10Extensions(extList)
                    .where((e) => !e.isInstalled)
                    .take(2);
                final topVideo = selectTopVideoExtensions(extList)
                    .where((e) => !e.isInstalled)
                    .take(2);
                final topNovel = selectTopNovelExtensions(extList)
                    .where((e) => !e.isInstalled)
                    .take(2);
                for (final ext in [...topManga, ...topVideo, ...topNovel]) {
                  try {
                    await ref.read(extensionActionsProvider).install(ext.pkgName);
                  } catch (_) {}
                }
              }
              // ignore: unused_result
              ref.refresh(sourceListProvider.future);
              onSelectDefaults?.call();
              toast?.show('Default Manga, Video & Novel sources installed');
            },
          ),
        ],
      ),
    );
  }
}
