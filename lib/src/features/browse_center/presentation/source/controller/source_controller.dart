// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../../../../utils/mixin/state_provider_mixin.dart';
import '../../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../../data/source_repository/source_repository.dart';
import '../../../domain/content_rating.dart';
import '../../../domain/extension/top_extensions.dart';
import '../../../domain/source/source_model.dart';
import '../../extension/controller/extension_controller.dart';

part 'source_controller.g.dart';

String normalizeSourceLang(SourceDto s) {
  final raw = (s.language?.code ?? s.lang).trim().toLowerCase();
  if (raw.startsWith('en-') || raw.startsWith('en_')) return 'en';
  if (raw.startsWith('ar-') || raw.startsWith('ar_')) return 'ar';
  return raw.isEmpty ? 'other' : raw;
}

@riverpod
Future<List<SourceDto>?> sourceList(Ref ref) =>
    ref.watch(sourceRepositoryProvider).getSourceList();

/// Applies the NSFW source filter; defaults to false unless enabled via Face ID.
/// Also enforces English & Arabic content languages only (`en`, `ar`, `all`, `localsourcelang`)
/// and excludes all video extensions/sources.
@riverpod
AsyncValue<List<SourceDto>?> visibleSourceList(Ref ref) {
  final showNsfw = ref.watch(showNSFWProvider).ifNull(false);
  final onlyNsfw = showNsfw && ref.watch(onlyNsfwModeProvider).ifNull(false);
  return ref.watch(sourceListProvider).copyWithData((list) {
    if (list == null) return null;
    final langAndTypeFiltered = [
      for (final e in list)
        if (!isVideoSource(e) && isAllowedContentLanguage(normalizeSourceLang(e)))
          e,
    ];
    if (!showNsfw) {
      return [
        ...langAndTypeFiltered.where((e) => !isNsfwFromWarning(e.contentWarning)),
      ];
    }
    if (onlyNsfw) {
      return [
        ...langAndTypeFiltered.where((e) => isNsfwFromWarning(e.contentWarning)),
      ];
    }
    return langAndTypeFiltered;
  });
}

/// Excludes hidden sources and sources belonging to disabled extensions;
/// the filter screen uses [visibleSourceList] so they can be unhidden.
@riverpod
AsyncValue<List<SourceDto>?> browsableSourceList(Ref ref) {
  final disabledExts = {
    for (final pkg in ref.watch(disabledExtensionsProvider) ?? const <String>[])
      pkg.trim().toLowerCase(),
  };
  return ref.watch(visibleSourceListProvider).copyWithData(
        (List<SourceDto>? list) => list == null
            ? list
            : [
                ...list.where(
                  (SourceDto e) =>
                      !e.isHidden &&
                      !disabledExts.contains(
                        e.$extension.pkgName.trim().toLowerCase(),
                      ),
                ),
              ],
      );
}

int _byName(SourceDto a, SourceDto b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

List<SourceDto> pinnedSourcesFrom(List<SourceDto> sources) =>
    [...sources.where((e) => e.isPinned)]..sort(_byName);

/// Groups non-pinned sources by normalized lowercase language code, with a separate last-used bucket; sorts each by name.
Map<String, List<SourceDto>> groupSourcesByLanguage(
  List<SourceDto> sources,
  String? lastUsedId,
) {
  final sourceMap = <String, List<SourceDto>>{};
  for (final e in sources) {
    if (!e.isPinned) {
      sourceMap.update(
        normalizeSourceLang(e),
        (value) => [...value, e],
        ifAbsent: () => [e],
      );
    }
    if (e.id == lastUsedId) sourceMap["lastUsed"] = [e];
  }
  for (final list in sourceMap.values) {
    list.sort(_byName);
  }
  return sourceMap;
}

/// Pinned sources filtered by the active language filter when languages are selected.
@riverpod
List<SourceDto> pinnedSources(Ref ref) {
  final allPinned = pinnedSourcesFrom(
    ref.watch(browsableSourceListProvider).value ?? const [],
  );
  final rawEnabled = ref.watch(sourceLanguageFilterProvider);
  if (rawEnabled == null) return allPinned;
  final enabledContentLangs = {
    for (final c in rawEnabled)
      if (c.toLowerCase() != 'lastused' &&
          c.toLowerCase() != 'localsourcelang')
        c.trim().toLowerCase(),
  };
  if (enabledContentLangs.isEmpty) return const <SourceDto>[];
  return [
    for (final s in allPinned)
      if (enabledContentLangs.contains(normalizeSourceLang(s))) s,
  ];
}

@riverpod
AsyncValue<Map<String, List<SourceDto>>> sourceMap(Ref ref) {
  final sourceListData = ref.watch(browsableSourceListProvider);
  final sourceLastUsed = ref.watch(sourceLastUsedProvider);
  return sourceListData.copyWithData(
    (data) => groupSourcesByLanguage(data ?? const [], sourceLastUsed),
  );
}

/// Includes hidden and pinned sources, grouped by lowercase language and sorted by visibility then name.
Map<String, List<SourceDto>> groupAllSourcesByLanguage(
  List<SourceDto> sources,
) {
  final sourceMap = <String, List<SourceDto>>{};
  for (final e in sources) {
    sourceMap.update(
      normalizeSourceLang(e),
      (value) => [...value, e],
      ifAbsent: () => [e],
    );
  }
  for (final list in sourceMap.values) {
    list.sort((a, b) => a.isHidden == b.isHidden
        ? _byName(a, b)
        : (a.isHidden ? 1 : -1));
  }
  return sourceMap;
}

/// Includes hidden and pinned sources so the filter screen & language dialog can see every language.
@riverpod
AsyncValue<Map<String, List<SourceDto>>> allSourcesByLanguage(Ref ref) {
  final sourceListData = ref.watch(visibleSourceListProvider);
  return sourceListData.copyWithData(
    (data) => groupAllSourcesByLanguage(data ?? const []),
  );
}

@riverpod
class SourceFilterLangMap extends _$SourceFilterLangMap {
  @override
  Map<String, bool> build() {
    final allMap = {...?ref.watch(allSourcesByLanguageProvider).value};
    final sourceMap = {...?ref.watch(sourceMapProvider).value};
    final enabledLanguages = ref.watch(sourceLanguageFilterProvider);
    final enabledSet = {
      for (final c in enabledLanguages ?? const <String>[])
        c.trim().toLowerCase(),
    };
    final keys = <String>{
      ...allMap.keys.map((k) => k.toLowerCase()),
      ...sourceMap.keys.map((k) => k.toLowerCase()),
    }
      ..remove("lastused")
      ..remove("lastUsed")
      ..remove("localsourcelang");
    return Map.fromIterable(
      keys,
      value: (element) => enabledSet.contains((element as String).toLowerCase()),
    );
  }

  void toggleLang(String langCode, bool value) {
    final target = langCode.trim().toLowerCase();
    if (!value) {
      ref.read(sourceLanguageFilterProvider.notifier).updateWithPreviousState(
            (enabledLanguages) => [
              for (final c in enabledLanguages ?? const <String>[])
                if (c.trim().toLowerCase() != target) c.trim().toLowerCase(),
            ],
          );
    } else {
      ref.read(sourceLanguageFilterProvider.notifier).updateWithPreviousState(
            (enabledLanguages) => {
              for (final c in enabledLanguages ?? const <String>[])
                c.trim().toLowerCase(),
              target,
            }.toList(),
          );
    }
  }
}

@riverpod
AsyncValue<Map<String, List<SourceDto>>?> sourceMapFiltered(Ref ref) {
  final sourceMapFiltered = <String, List<SourceDto>>{};
  final sourceMapData = ref.watch(sourceMapProvider);
  final sourceMap = {...?sourceMapData.value};
  final rawEnabled = ref.watch(sourceLanguageFilterProvider) ??
      const <String>['all', 'lastUsed', 'en', 'ar', 'localsourcelang'];
  final enabledSet = {
    for (final c in rawEnabled) c.trim().toLowerCase(),
  };
  final enabledContentLangs = {
    for (final c in enabledSet)
      if (c != 'lastused' &&
          c != 'localsourcelang' &&
          isAllowedContentLanguage(c))
        c,
  };

  for (final entry in sourceMap.entries) {
    final key = entry.key;
    final keyLower = key.toLowerCase();
    if (key == 'lastUsed' || keyLower == 'lastused') {
      if (enabledSet.contains('lastused') || enabledSet.contains('lastUsed')) {
        final filtered = [
          for (final s in entry.value)
            if (enabledContentLangs.contains(normalizeSourceLang(s))) s,
        ];
        if (filtered.isNotEmpty) {
          sourceMapFiltered['lastUsed'] = filtered;
        }
      }
    } else if (keyLower == 'localsourcelang') {
      if (enabledSet.contains('localsourcelang') && enabledContentLangs.isNotEmpty) {
        sourceMapFiltered['localsourcelang'] = entry.value;
      }
    } else if (enabledContentLangs.contains(keyLower)) {
      sourceMapFiltered[keyLower] = entry.value;
    }
  }
  return sourceMapData.copyWithData((e) => sourceMapFiltered);
}

/// Includes pinned sources first; they are absent from the grouped source map.
@riverpod
AsyncValue<List<SourceDto>> searchableSources(Ref ref) {
  final mapData = ref.watch(sourceMapFilteredProvider);
  final pinned = ref.watch(pinnedSourcesProvider);
  return mapData.copyWithData((map) {
    final rest = <SourceDto>[];
    (map ?? const <String, List<SourceDto>>{}).forEach((key, value) {
      if (key != 'lastUsed') rest.addAll(value);
    });
    return [...pinned, ...rest];
  });
}

@riverpod
List<SourceDto>? sourceQuery(Ref ref, {String? query}) {
  final sourceMap = {...?ref.watch(sourceMapFilteredProvider).value}
    ..remove('lastUsed');
  if (query.isNotBlank) {
    return sourceMap.values
        .expand((list) => list.where(
              (element) => element.name.query(query),
            ))
        .toList();
  }
  return sourceMap.values.expand((list) => list).toList();
}

@riverpod
AsyncValue<Map<String, List<SourceDto>>?> sourceMapFilteredAndQueried(Ref ref) {
  final sourceMapData = ref.watch(sourceMapFilteredProvider);
  final sourceMap = {...?sourceMapData.value};
  final query = ref.watch(sourceSearchQueryProvider);
  if (query.isBlank) return sourceMapData;
  return sourceMapData.copyWithData(
    (e) => sourceMap.map<String, List<SourceDto>>(
      (key, value) => MapEntry(
        key,
        value.where((element) => element.name.query(query)).toList(),
      ),
    ),
  );
}

@Riverpod(keepAlive: true)
class SourceSearchQuery extends _$SourceSearchQuery
    with StateProviderMixin<String?> {
  @override
  String? build() => null;
}

@riverpod
class SourceLanguageFilter extends _$SourceLanguageFilter
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.sourceLanguageFilter);
}

@riverpod
class SourceLastUsed extends _$SourceLastUsed
    with SharedPreferenceClientMixin<String> {
  @override
  String? build() => initialize(DBKeys.sourceLastUsed);
}

@riverpod
class SourceRecentIds extends _$SourceRecentIds
    with SharedPreferenceClientMixin<List<String>> {
  static const maxRecentSources = 4;

  @override
  List<String>? build() => initialize(DBKeys.sourceRecentIds);

  void recordOpened(String id) {
    final current = state ?? const <String>[];
    if (current.firstOrNull == id) return;
    final next = [id, for (final e in current) if (e != id) e];
    update(next.take(maxRecentSources).toList());
  }
}
