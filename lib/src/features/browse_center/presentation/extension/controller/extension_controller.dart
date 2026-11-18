// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../../../../utils/mixin/state_provider_mixin.dart';
import '../../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../../data/extension_repository/extension_repository.dart';
import '../../../domain/content_rating.dart';
import '../../../domain/extension/extension_model.dart';
import '../../../domain/extension/top_extensions.dart';

part 'extension_controller.g.dart';

/// Persisted list of disabled extension package names (lowercase).
/// When an extension is in this list, all its sources are hidden from Browse
/// without uninstalling the extension APK/bundle.
class DisabledExtensionsNotifier extends Notifier<List<String>?>
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.disabledExtensions);

  bool isDisabled(String pkgName) {
    final normalized = pkgName.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return (state ?? const <String>[])
        .any((e) => e.trim().toLowerCase() == normalized);
  }

  void setEnabled(String pkgName, bool enabled) {
    final normalized = pkgName.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final current = {
      for (final e in state ?? const <String>[]) e.trim().toLowerCase(),
    };
    if (enabled) {
      current.remove(normalized);
    } else {
      current.add(normalized);
    }
    update(current.toList());
  }
}

final disabledExtensionsProvider =
    NotifierProvider<DisabledExtensionsNotifier, List<String>?>(
      DisabledExtensionsNotifier.new,
    );

/// Persisted list of disabled extension store URLs (normalized).
class DisabledExtensionStoresNotifier extends Notifier<List<String>?>
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.disabledExtensionStores);

  bool isStoreDisabled(String indexUrl) {
    final normalized = normalizeExtensionStoreUrl(indexUrl);
    if (normalized.isEmpty) return false;
    return (state ?? const <String>[])
        .any((u) => normalizeExtensionStoreUrl(u) == normalized);
  }

  void setStoreEnabled(String indexUrl, bool enabled) {
    final normalized = normalizeExtensionStoreUrl(indexUrl);
    if (normalized.isEmpty) return;
    final current = [
      for (final u in state ?? const <String>[])
        if (normalizeExtensionStoreUrl(u) != normalized) u,
    ];
    if (!enabled) {
      current.add(indexUrl.trim());
    }
    update(current);
  }
}

final disabledExtensionStoresProvider =
    NotifierProvider<DisabledExtensionStoresNotifier, List<String>?>(
      DisabledExtensionStoresNotifier.new,
    );

String normalizeExtensionLang(Extension e) {
  final raw = (e.language?.code ?? e.lang).trim().toLowerCase();
  return raw.isEmpty ? 'other' : raw;
}

/// Deduplicates extensions by [Extension.pkgName], preferring installed,
/// then hasUpdate, then highest versionCodeLong.
List<Extension> deduplicateExtensions(Iterable<Extension> input) {
  final byPkg = <String, Extension>{};
  for (final ext in input) {
    final key = ext.pkgName.trim().toLowerCase();
    final existing = byPkg[key];
    if (existing == null) {
      byPkg[key] = ext;
      continue;
    }
    final extInstalled = ext.isInstalled.ifNull();
    final existingInstalled = existing.isInstalled.ifNull();
    if (extInstalled && !existingInstalled) {
      byPkg[key] = ext;
    } else if (extInstalled == existingInstalled) {
      final extVer = int.tryParse(ext.versionCodeLong) ?? 0;
      final existingVer = int.tryParse(existing.versionCodeLong) ?? 0;
      if (extVer > existingVer) {
        byPkg[key] = ext;
      }
    }
  }
  return byPkg.values.toList();
}

@riverpod
Future<List<Extension>?> extension(Ref ref) {
  final result =
      ref.watch(extensionRepositoryProvider).getExtensionListStream();
  ref.keepAlive();
  return result;
}

@riverpod
AsyncValue<Map<String, List<Extension>>> extensionMap(Ref ref) {
  final extensionMap = <String, List<Extension>>{};
  final extensionListData = ref.watch(extensionProvider);
  final extensionList = deduplicateExtensions([
    ...?extensionListData.value,
  ]);
  final showNsfw = ref.watch(showNSFWProvider).ifNull(false);
  final onlyNsfw = showNsfw && ref.watch(onlyNsfwModeProvider).ifNull(false);
  final disabledStoresRaw =
      ref.watch(disabledExtensionStoresProvider) ?? const <String>[];
  final disabledStoreSet = {
    for (final u in disabledStoresRaw) normalizeExtensionStoreUrl(u),
  };
  for (final e in extensionList) {
    final isNsfw = isNsfwFromWarning(e.contentWarning);
    if (!showNsfw && isNsfw) continue;
    if (onlyNsfw && !isNsfw) continue;
    if (!e.isInstalled.ifNull()) {
      final storeUrl = e.extensionStore?.indexUrl ?? e.storeIndexUrl ?? '';
      if (storeUrl.isNotEmpty &&
          disabledStoreSet.contains(normalizeExtensionStoreUrl(storeUrl))) {
        continue;
      }
    }
    if (e.isInstalled.ifNull()) {
      if (e.hasUpdate.ifNull()) {
        extensionMap.update(
          "update",
          (value) => [...value, e],
          ifAbsent: () => [e],
        );
      } else {
        extensionMap.update(
          "installed",
          (value) => [...value, e],
          ifAbsent: () => [e],
        );
      }
    } else {
      extensionMap.update(
        normalizeExtensionLang(e),
        (value) => [...value, e],
        ifAbsent: () => [e],
      );
    }
  }
  for (final list in extensionMap.values) {
    list.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }
  return extensionListData.copyWithData((p0) => extensionMap);
}

@riverpod
List<String> extensionFilterLangList(Ref ref) {
  final extensionList = deduplicateExtensions([
    ...?ref.watch(extensionProvider).value,
  ]);
  final showNsfw = ref.watch(showNSFWProvider).ifNull(false);
  final onlyNsfw = showNsfw && ref.watch(onlyNsfwModeProvider).ifNull(false);
  final codes = <String>{};
  for (final e in extensionList) {
    final isNsfw = isNsfwFromWarning(e.contentWarning);
    if (!showNsfw && isNsfw) continue;
    if (onlyNsfw && !isNsfw) continue;
    codes.add(normalizeExtensionLang(e));
  }
  final mapKeys = {...?ref.watch(extensionMapProvider).value?.keys};
  mapKeys.remove("installed");
  mapKeys.remove("update");
  codes.addAll(mapKeys.map((k) => k.toLowerCase()));
  return codes.toList()..sort();
}

@riverpod
class ExtensionLanguageFilter extends _$ExtensionLanguageFilter
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.extensionLanguageFilter);
}

@riverpod
AsyncValue<Map<String, List<Extension>>> extensionMapFiltered(Ref ref) {
  final extensionMapFiltered = <String, List<Extension>>{};
  final extensionMapData = ref.watch(extensionMapProvider);
  final extensionMap = {...?extensionMapData.value};
  final rawEnabled = ref.watch(extensionLanguageFilterProvider) ??
      const <String>['installed', 'update', 'en', 'all'];
  final enabledSet = {
    for (final code in rawEnabled) code.trim().toLowerCase(),
  };
  final enabledContentLangs = {
    for (final code in enabledSet)
      if (code != 'installed' && code != 'update') code,
  };

  bool matchesSelectedLangs(Extension ext) {
    if (enabledContentLangs.isEmpty) return false;
    final lang = normalizeExtensionLang(ext);
    return enabledContentLangs.contains(lang);
  }

  for (final entry in extensionMap.entries) {
    final keyLower = entry.key.toLowerCase();
    if (keyLower == 'installed' || keyLower == 'update') {
      if (enabledSet.contains(keyLower) || enabledContentLangs.isNotEmpty) {
        final filtered = entry.value.where(matchesSelectedLangs).toList();
        if (filtered.isNotEmpty) {
          extensionMapFiltered[entry.key] = filtered;
        }
      }
    } else if (enabledContentLangs.contains(keyLower)) {
      extensionMapFiltered[keyLower] = entry.value;
    }
  }
  return extensionMapData.copyWithData((p0) => extensionMapFiltered);
}

@riverpod
AsyncValue<Map<String, List<Extension>>> extensionMapFilteredAndQueried(
  Ref ref,
) {
  final extensionMapData = ref.watch(extensionMapFilteredProvider);
  final extensionMap = {...?extensionMapData.value};
  final query = ref.watch(extensionQueryProvider);
  if (query.isBlank) return extensionMapData;
  return extensionMapData.copyWithData(
    (e) => extensionMap.map<String, List<Extension>>(
      (key, value) => MapEntry(
        key,
        value.where((element) => element.name.query(query)).toList(),
      ),
    ),
  );
}

@riverpod
class ExtensionQuery extends _$ExtensionQuery with StateProviderMixin<String?> {
  @override
  String? build() => null;
}
