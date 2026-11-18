// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../constants/language_list.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/compact_switch.dart';
import '../../../../../widgets/popup_widgets/pop_button.dart';
import '../../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../../domain/language/flag_emoji.dart';
import '../../../domain/language/language_model.dart';
import '../controller/extension_controller.dart';

class ExtensionLanguageFilterDialog extends HookConsumerWidget {
  const ExtensionLanguageFilterDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCodes = ref.watch(extensionFilterLangListProvider);
    final rawEnabled = ref.watch(extensionLanguageFilterProvider) ??
        const <String>['installed', 'update', 'en', 'all'];
    final enabledSet = {
      for (final c in rawEnabled) c.trim().toLowerCase(),
    };
    final searchQuery = useState('');

    final sortedCodes = [...languageCodes]
      ..sort((a, b) {
        final ae = enabledSet.contains(a.toLowerCase());
        final be = enabledSet.contains(b.toLowerCase());
        if (ae != be) return ae ? -1 : 1;
        return a.compareTo(b);
      });

    final filteredCodes = searchQuery.value.trim().isEmpty
        ? sortedCodes
        : sortedCodes.where((raw) {
            final code = raw.toLowerCase();
            final q = searchQuery.value.trim().toLowerCase();
            final lang = languageMap[code];
            return code.contains(q) ||
                (lang?.name?.toLowerCase().contains(q) ?? false) ||
                (lang?.nativeName?.toLowerCase().contains(q) ?? false);
          }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(context.l10n.languages)),
          TextButton(
            onPressed: () {
              ref.read(extensionLanguageFilterProvider.notifier).update([
                'installed',
                'update',
                ...languageCodes.map((c) => c.toLowerCase()),
              ]);
            },
            child: Text(context.l10n.all),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(extensionLanguageFilterProvider.notifier)
                  .update(const <String>['installed', 'update']);
            },
            child: Text(context.l10n.none),
          ),
        ],
      ),
      content: SizedBox(
        height: context.heightScale(scale: .6),
        width: context.widthScale(
          scale: context.windowSizeClass >= WindowSizeClass.medium ? .5 : .85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NsfwFilterChipsRow(),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => searchQuery.value = v,
              decoration: InputDecoration(
                hintText: context.l10n.search,
                prefixIcon: const Icon(FluentIcons.search_24_regular, size: 18),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filteredCodes.length,
                itemBuilder: (context, index) {
                  final String languageCode =
                      filteredCodes[index].toLowerCase();
                  final Language? language = languageMap[languageCode];
                  final flag = flagEmojiForLang(languageCode);
                  final isEnabled = enabledSet.contains(languageCode);
                  final label =
                      language?.nativeName ??
                      language?.name ??
                      languageCode.toUpperCase();
                  return CompactSwitchListTile(
                    key: ValueKey('ext_lang_$languageCode'),
                    value: isEnabled,
                    onChanged: (value) {
                      final next = {...enabledSet};
                      if (value) {
                        next.add(languageCode);
                      } else {
                        next.remove(languageCode);
                      }
                      ref
                          .read(extensionLanguageFilterProvider.notifier)
                          .update(next.toList());
                    },
                    title: Text('$flag $label'),
                    subtitle:
                        (language?.name).isNotBlank &&
                            language?.nativeName != language?.name
                        ? Text(language!.name!)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [PopButton(popText: context.l10n.close)],
    );
  }
}
