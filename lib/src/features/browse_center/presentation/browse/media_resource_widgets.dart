// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../constants/db_keys.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/launch_url_in_web.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../domain/extension/top_extensions.dart';

IconData iconForResourceCategory(ResourceCategory category) =>
    switch (category) {
      ResourceCategory.videos => FluentIcons.video_24_regular,
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
          ActionChip(
            avatar: const Icon(FluentIcons.checkmark_circle_24_regular, size: 16),
            label: const Text('Select Defaults'),
            onPressed: () {
              ref.read(selectedMediaResourcesProvider.notifier).selectDefaults();
              onSelectDefaults?.call();
              ref
                  .read(toastProvider)
                  ?.show('Default Video, Manga, Comic & Novel resources selected');
            },
          ),
        ],
      ),
    );
  }
}

List<MediaResourceItem> visibleCatalogForCategory(
  WidgetRef ref,
  ResourceCategory category, {
  String? query,
  bool onlySelected = false,
}) {
  final showNsfw = ref.watch(showNSFWProvider).ifNull(false);
  final selectedIds = (ref.watch(selectedMediaResourcesProvider) ??
          (DBKeys.selectedMediaResources.initial as List<String>))
      .toSet();
  final search = query?.trim().toLowerCase() ?? '';

  return [
    for (final item in kMediaResourceCatalog)
      if ((category == ResourceCategory.all || item.category == category) &&
          (showNsfw || !item.isNsfw) &&
          (!onlySelected || selectedIds.contains(item.id)) &&
          (search.isEmpty ||
              item.name.toLowerCase().contains(search) ||
              item.subtitle.toLowerCase().contains(search)))
        item,
  ];
}

class MediaResourceExtensionTile extends ConsumerWidget {
  const MediaResourceExtensionTile({
    super.key,
    required this.item,
  });

  final MediaResourceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedMediaResourcesProvider) ??
        (DBKeys.selectedMediaResources.initial as List<String>);
    final isSelected = selectedIds.contains(item.id);
    final scheme = context.theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        child: Icon(iconForResourceCategory(item.category)),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.isNsfw) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '18+',
                style: context.textTheme.labelSmall?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${item.lang} • ${item.subtitle}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open resource',
            icon: const Icon(FluentIcons.open_24_regular),
            onPressed: () => launchUrlInAppBrowser(
              context,
              item.url,
              ref.read(toastProvider),
            ),
          ),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(selectedMediaResourcesProvider.notifier).toggle(item.id),
            child: Text(isSelected ? 'Selected' : 'Select'),
          ),
        ],
      ),
      onTap: () =>
          ref.read(selectedMediaResourcesProvider.notifier).toggle(item.id),
    );
  }
}

class MediaResourceSourceTile extends ConsumerWidget {
  const MediaResourceSourceTile({
    super.key,
    required this.item,
  });

  final MediaResourceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colorScheme;
    final isVideo = item.category == ResourceCategory.videos;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(iconForResourceCategory(item.category)),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: () => launchUrlInAppBrowser(
          context,
          item.url,
          ref.read(toastProvider),
        ),
        icon: Icon(
          isVideo
              ? FluentIcons.play_24_regular
              : FluentIcons.open_24_regular,
          size: 18,
        ),
        label: Text(isVideo ? 'Watch' : 'Open'),
      ),
      onTap: () => launchUrlInAppBrowser(
        context,
        item.url,
        ref.read(toastProvider),
      ),
    );
  }
}
