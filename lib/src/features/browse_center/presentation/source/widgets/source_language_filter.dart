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
import '../controller/source_controller.dart';

class SourceLanguageFilter extends HookConsumerWidget {
  const SourceLanguageFilter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCodesMap = ref.watch(sourceFilterLangMapProvider);
    final allSourcesMap = ref.watch(allSourcesByLanguageProvider).value ?? const {};
    final searchQuery = useState('');

    final languageCodes = languageCodesMap.keys.toList()
      ..sort((a, b) {
        final aEnabled = languageCodesMap[a].ifNull();
        final bEnabled = languageCodesMap[b].ifNull();
        if (aEnabled != bEnabled) return aEnabled ? -1 : 1;
        return a.compareTo(b);
      });

    final filteredCodes = searchQuery.value.trim().isEmpty
        ? languageCodes
        : languageCodes.where((code) {
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
              ref.read(sourceLanguageFilterProvider.notifier).update([
                'lastUsed',
                'localsourcelang',
                ...languageCodesMap.keys.map((k) => k.toLowerCase()),
              ]);
            },
            child: Text(context.l10n.all),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(sourceLanguageFilterProvider.notifier)
                  .update(const <String>[]);
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
              child: filteredCodes.isEmpty
                  ? Center(child: Text(context.l10n.noSourcesFound))
                  : ListView.builder(
                      itemCount: filteredCodes.length,
                      itemBuilder: (context, index) {
                        final String languageCode = filteredCodes[index];
                        final Language? language = languageMap[languageCode];
                        final flag = flagEmojiForLang(languageCode);
                        final count = allSourcesMap[languageCode]?.length ?? 0;
                        final label =
                            language?.nativeName ??
                            language?.name ??
                            languageCode.toUpperCase();
                        return CompactSwitchListTile(
                          key: ValueKey('source_lang_$languageCode'),
                          value: languageCodesMap[languageCode].ifNull(),
                          onChanged: (value) {
                            ref
                                .read(sourceFilterLangMapProvider.notifier)
                                .toggleLang(languageCode, value);
                          },
                          title: Text(
                            count > 0 ? '$flag $label ($count)' : '$flag $label',
                          ),
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
