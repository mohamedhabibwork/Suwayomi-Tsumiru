// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../routes/router_config.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../domain/extension/top_extensions.dart';

IconData iconForResourceCategory(ResourceCategory category) =>
    switch (category) {
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
    final activeSort = ref.watch(selectedExtensionSortProvider);
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
          PopupMenuButton<ExtensionSortOption>(
            tooltip: 'Sort Sources & Extensions',
            onSelected: (option) => ref
                .read(selectedExtensionSortProvider.notifier)
                .select(option),
            itemBuilder: (context) => [
              for (final opt in ExtensionSortOption.values)
                PopupMenuItem(
                  value: opt,
                  child: Row(
                    children: [
                      Icon(
                        activeSort == opt
                            ? FluentIcons.checkmark_24_regular
                            : FluentIcons.arrow_sort_24_regular,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(opt.label),
                    ],
                  ),
                ),
            ],
            child: Chip(
              avatar: const Icon(FluentIcons.arrow_sort_24_regular, size: 16),
              label: Text('Sort: ${activeSort.label}'),
            ),
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
            avatar: const Icon(FluentIcons.shield_task_24_regular, size: 16),
            label: Text(context.l10n.cloudflareBypass),
            onPressed: () => const ServerNetworkRoute(
              highlight: 'flareSolverr',
            ).push(context),
          ),
        ],
      ),
    );
  }
}
