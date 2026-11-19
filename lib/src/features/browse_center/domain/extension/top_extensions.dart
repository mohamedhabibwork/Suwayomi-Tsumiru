// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/db_keys.dart';
import '../../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../source/source_model.dart';
import 'extension_model.dart';

/// Official Keiyoushi extension repository index URL (Protobuf).
const kKeiyoushiStoreUrl =
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb';

/// Legacy GitHub redirect URL for Keiyoushi (kept for normalization/deduplication).
const kKeiyoushiLegacyGithubUrl =
    'https://github.com/keiyoushi/extensions/raw/repo/index.pb';

/// Yuzono Anime & Video Protobuf extension store.
const kYuzonoAnimePbStoreUrl =
    'https://x.ujol.workers.dev/yuzono/anime/index.pb';

/// Aidoku Community Sources JSON store.
const kAidokuCommunityStoreUrl =
    'https://aidoku-community.github.io/sources/index.min.json';

/// Mangayomi Manga Extensions JSON store.
const kMangayomiMangaStoreUrl =
    'https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/refs/heads/main/index.json';

/// Mangayomi Anime & Video Extensions JSON store.
const kMangayomiAnimeStoreUrl =
    'https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/refs/heads/main/anime_index.json';

/// Mangayomi Novel & Book Extensions JSON store.
const kMangayomiNovelStoreUrl =
    'https://raw.githubusercontent.com/m2k3a/mangayomi-extensions/refs/heads/main/novel_index.json';

/// LNReader Novel Plugins JSON store (372 Light Novel & Web Novel sources).
const kLnReaderNovelStoreUrl =
    'https://raw.githubusercontent.com/LNReader/lnreader-plugins/plugins/v3.0.0/.dist/plugins.min.json';

/// Nyora Mihon Extension Store (from Miyomi Extensions Directory).
const kNyoraMihonStoreUrl =
    'https://raw.githubusercontent.com/Nyora-Manga/nyora-mihon/main/index.min.json';

/// Suwayomi Official Extension Store (from Miyomi Extensions Directory).
const kSuwayomiOfficialStoreUrl =
    'https://raw.githubusercontent.com/Suwayomi/tachiyomi-extension/repo/index.min.json';

/// Yuzono Cursed Manga Repo (Protobuf, from Miyomi Extensions Directory).
const kYuzonoCursedMangaStoreUrl =
    'https://github.com/yuzono/cursed-manga-repo/raw/repo/index.pb';

/// Kavita Extension Store (from Miyomi Extensions Directory).
const kKavitaStoreUrl =
    'https://raw.githubusercontent.com/Kareadita/tach-extension/repo/index.min.json';

/// Novel Sourcery Extension Store (Protobuf, from Miyomi Extensions Directory).
const kNovelSourceryStoreUrl =
    'https://github.com/novelsourcery/extensions/raw/repo/index.pb';

/// IReader Novel Extensions Store (from Miyomi Extensions Directory).
const kIReaderNovelStoreUrl =
    'https://raw.githubusercontent.com/IReaderorg/IReader-extensions/repov2/index.min.json';

/// Bunori Light Novel Extensions Store (from Miyomi Extensions Directory).
const kBunoriNovelStoreUrl =
    'https://bunoriapp.github.io/extensions/index.min.json';

/// Swakshan Mangayomi Manga Store (from Miyomi Extensions Directory).
const kSwakshanMangaStoreUrl =
    'https://raw.githubusercontent.com/Swakshan/mangayomi-swak-extensions/refs/heads/main/index.json';

/// Swakshan Mangayomi Novel Store (from Miyomi Extensions Directory).
const kSwakshanNovelStoreUrl =
    'https://raw.githubusercontent.com/Swakshan/mangayomi-swak-extensions/refs/heads/main/novel_index.json';

/// Kegareta Sauces Manga Store (from Miyomi Extensions Directory).
const kKegaretaMangaStoreUrl =
    'https://raw.githubusercontent.com/gato404/kegareta-sauces/main/index.json';

/// Mally Mangayomi Manga Store (from Miyomi Extensions Directory).
const kMallyMangaStoreUrl =
    'https://raw.githubusercontent.com/Mallyd11/mangayomi-anime-extensions/main/index.json';

/// Mally Mangayomi Novel Store (from Miyomi Extensions Directory).
const kMallyNovelStoreUrl =
    'https://raw.githubusercontent.com/Mallyd11/mangayomi-anime-extensions/main/novel_index.json';

/// Livid96 Aniyomi Adult Extensions store (18+ / NSFW).
const kLividAdultVideoStoreUrl =
    'https://raw.githubusercontent.com/Livid96/Aniyomi-Adult-Extensions/main/index.min.json';

/// Allowed content language codes across the app: English (`en`), Arabic (`ar`),
/// multi-language (`all`), and Local Source (`localsourcelang`).
const Set<String> kAllowedContentLanguageCodes = {
  'en',
  'ar',
  'all',
  'localsourcelang',
};

bool isAllowedContentLanguage(String rawCode) {
  final code = rawCode.trim().toLowerCase();
  if (code.isEmpty) return false;
  if (kAllowedContentLanguageCodes.contains(code)) return true;
  if (code.startsWith('en-') || code.startsWith('en_')) return true;
  if (code.startsWith('ar-') || code.startsWith('ar_')) return true;
  return false;
}

/// Returns true if [url] is one of the legacy redundant mirror URLs or video stores.
bool isRedundantDuplicateStoreUrl(String url) {
  final lower = url.trim().toLowerCase();
  return lower == kKeiyoushiLegacyGithubUrl.toLowerCase() ||
      lower.contains('mo350az/extensions-no-nsfw') ||
      lower.contains('felipegfa/extensoes') ||
      lower.contains('dddinmx/mangadock-extensions') ||
      lower.contains('yuzono/anime') ||
      lower.contains('anime_index.json') ||
      lower.contains('aniyomi-adult-extensions');
}

/// Normalizes an extension store URL so equivalent URLs (e.g. github.com/raw vs
/// raw.githubusercontent.com, /refs/heads/, or repo.json vs index.min.json vs
/// index.pb) compare equal and are never duplicated.
String normalizeExtensionStoreUrl(String url) {
  var u = url.trim().toLowerCase();
  if (u.endsWith('/')) u = u.substring(0, u.length - 1);
  u = u.replaceFirst(
    'https://github.com/keiyoushi/extensions/raw/repo/',
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/',
  );
  u = u.replaceAll('/refs/heads/', '/');
  for (final suffix in ['/repo.json', '/index.min.json', '/index.pb']) {
    if (u.endsWith(suffix)) {
      u = '${u.substring(0, u.length - suffix.length)}/_store_index_';
      break;
    }
  }
  return u;
}

bool isExtensionStoreUrlPresent(
  String candidateUrl,
  Iterable<String> existingUrls,
) {
  final target = normalizeExtensionStoreUrl(candidateUrl);
  for (final existing in existingUrls) {
    if (existing.trim() == candidateUrl.trim() ||
        normalizeExtensionStoreUrl(existing) == target) {
      return true;
    }
  }
  return false;
}

class CuratedStoreSpec {
  const CuratedStoreSpec({
    required this.name,
    required this.subtitle,
    required this.indexUrl,
    required this.category,
    this.isDefault = false,
    this.isNsfw = false,
  });

  final String name;
  final String subtitle;
  final String indexUrl;
  final ResourceCategory category;
  final bool isDefault;
  final bool isNsfw;
}

const List<CuratedStoreSpec> kCuratedExtensionStores = [
  CuratedStoreSpec(
    name: 'Keiyoushi Official Store (Miyomi)',
    subtitle: 'Top Manga, Manhwa, Manhua & Webtoon extensions (EN & AR)',
    indexUrl: kKeiyoushiStoreUrl,
    category: ResourceCategory.manga,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Nyora Mihon Extension Store (Miyomi)',
    subtitle: 'Miyomi curated Manga & Webtoon extension repository (EN & AR)',
    indexUrl: kNyoraMihonStoreUrl,
    category: ResourceCategory.manga,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Suwayomi Official Extension Store (Miyomi)',
    subtitle: 'Suwayomi Tachiyomi Manga & Comic extensions (EN & AR)',
    indexUrl: kSuwayomiOfficialStoreUrl,
    category: ResourceCategory.manga,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Yuzono Cursed Manga Repo (Miyomi)',
    subtitle: 'Yuzono Manga & Comic extensions repository',
    indexUrl: kYuzonoCursedMangaStoreUrl,
    category: ResourceCategory.manga,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Kavita Extension Store (Miyomi)',
    subtitle: 'Kavita self-hosted Manga & Comic reader extension',
    indexUrl: kKavitaStoreUrl,
    category: ResourceCategory.manga,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'LNReader Novel Plugins Store (Miyomi)',
    subtitle: 'Light Novel & Web Novel sources (English & Arabic)',
    indexUrl: kLnReaderNovelStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Novel Sourcery Store (Miyomi)',
    subtitle: 'Light Novel & Web Novel protobuf repository',
    indexUrl: kNovelSourceryStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'IReader Novel Extensions (Miyomi)',
    subtitle: 'IReader Light Novel & Book sources (English & Arabic)',
    indexUrl: kIReaderNovelStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Bunori Light Novel Extensions (Miyomi)',
    subtitle: 'Bunori Light Novel & Web Novel extensions',
    indexUrl: kBunoriNovelStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Mangayomi Novel & Book Store (m2k3a • Miyomi)',
    subtitle: 'RoyalRoad, Web Novel Translations & free book sources',
    indexUrl: kMangayomiNovelStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Swakshan Novel Store (Miyomi)',
    subtitle: 'Swakshan Mangayomi Light Novel & Book sources',
    indexUrl: kSwakshanNovelStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Mally Novel Store (Miyomi)',
    subtitle: 'Mally Mangayomi Light Novel & Book sources',
    indexUrl: kMallyNovelStoreUrl,
    category: ResourceCategory.novels,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Aidoku Community Sources (Miyomi)',
    subtitle: 'Aidoku Manga & Comic sources (English & Arabic)',
    indexUrl: kAidokuCommunityStoreUrl,
    category: ResourceCategory.other,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Mangayomi Extensions Store (m2k3a • Miyomi)',
    subtitle: 'Mangayomi Manga & Comic extensions (English & Arabic)',
    indexUrl: kMangayomiMangaStoreUrl,
    category: ResourceCategory.other,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Swakshan Manga Store (Miyomi)',
    subtitle: 'Swakshan Mangayomi Manga & Webtoon extensions',
    indexUrl: kSwakshanMangaStoreUrl,
    category: ResourceCategory.other,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Kegareta Sauces Manga Store (Miyomi)',
    subtitle: 'Kegareta Sauces Mangayomi Manga & Comic sources',
    indexUrl: kKegaretaMangaStoreUrl,
    category: ResourceCategory.other,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Mally Manga Store (Miyomi)',
    subtitle: 'Mally Mangayomi Manga & Comic sources',
    indexUrl: kMallyMangaStoreUrl,
    category: ResourceCategory.other,
    isDefault: true,
  ),
];

enum ResourceCategory {
  all('All Sources'),
  manga('Manga & Webtoons'),
  novels('Novels & Books'),
  comics('Comics'),
  other('Aidoku & Mangayomi');

  const ResourceCategory(this.label);
  final String label;
}

enum ExtensionSortOption {
  nameAsc('Name (A–Z)'),
  nameDesc('Name (Z–A)'),
  language('Language (AR / EN)'),
  enabledFirst('Enabled First');

  const ExtensionSortOption(this.label);
  final String label;
}

bool isNovelExtension(Extension e) {
  final pkg = e.pkgName.toLowerCase();
  final name = e.name.toLowerCase();
  return pkg.contains('.novelextension.') || name.contains('(novel)');
}

bool isVideoExtension(Extension e) {
  if (isNovelExtension(e)) return false;
  final pkg = e.pkgName.toLowerCase();
  final name = e.name.toLowerCase();
  return pkg.contains('.animeextension.') ||
      name.contains('(video)') ||
      name.contains('aniyomi:');
}

bool isAidokuOrMangayomiExtension(Extension e) {
  final pkg = e.pkgName.toLowerCase();
  return (pkg.startsWith('aidoku.') || pkg.startsWith('mangayomi.')) &&
      !isVideoExtension(e) &&
      !isNovelExtension(e);
}

bool isComicExtension(Extension e) {
  final name = e.name.toLowerCase();
  final pkg = e.pkgName.toLowerCase();
  return !isVideoExtension(e) &&
      !isNovelExtension(e) &&
      (name.contains('comic') ||
          name.contains('webtoon') ||
          name.contains('tapas') ||
          pkg.contains('comic') ||
          pkg.contains('webtoon'));
}

bool matchesExtensionCategory(Extension e, ResourceCategory category) =>
    !isVideoExtension(e) &&
    switch (category) {
      ResourceCategory.all => true,
      ResourceCategory.novels => isNovelExtension(e),
      ResourceCategory.comics => isComicExtension(e),
      ResourceCategory.other => isAidokuOrMangayomiExtension(e),
      ResourceCategory.manga =>
        !isNovelExtension(e) && !isAidokuOrMangayomiExtension(e),
    };

bool isNovelSource(SourceDto s) {
  final name = s.name.toLowerCase();
  final display = s.displayName.toLowerCase();
  final pkg = s.$extension.pkgName.toLowerCase();
  return pkg.contains('.novelextension.') ||
      name.contains('(novel)') ||
      display.contains('(novel)');
}

bool isVideoSource(SourceDto s) {
  if (isNovelSource(s)) return false;
  final name = s.name.toLowerCase();
  final display = s.displayName.toLowerCase();
  final pkg = s.$extension.pkgName.toLowerCase();
  return pkg.contains('.animeextension.') ||
      name.contains('(video)') ||
      display.contains('(video)');
}

bool isAidokuOrMangayomiSource(SourceDto s) {
  final pkg = s.$extension.pkgName.toLowerCase();
  return (pkg.startsWith('aidoku.') || pkg.startsWith('mangayomi.')) &&
      !isVideoSource(s) &&
      !isNovelSource(s);
}

bool isComicSource(SourceDto s) {
  final name = s.name.toLowerCase();
  final pkg = s.$extension.pkgName.toLowerCase();
  return !isVideoSource(s) &&
      !isNovelSource(s) &&
      (name.contains('comic') ||
          name.contains('webtoon') ||
          name.contains('tapas') ||
          pkg.contains('comic') ||
          pkg.contains('webtoon'));
}

bool matchesSourceCategory(SourceDto s, ResourceCategory category) =>
    !isVideoSource(s) &&
    switch (category) {
      ResourceCategory.all => true,
      ResourceCategory.novels => isNovelSource(s),
      ResourceCategory.comics => isComicSource(s),
      ResourceCategory.other => isAidokuOrMangayomiSource(s),
      ResourceCategory.manga =>
        !isNovelSource(s) && !isAidokuOrMangayomiSource(s),
    };

class SelectedMediaResources extends Notifier<List<String>?>
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.selectedMediaResources);

  void selectDefaults() {
    update(const <String>[]);
  }
}

final selectedMediaResourcesProvider =
    NotifierProvider<SelectedMediaResources, List<String>?>(
      SelectedMediaResources.new,
    );

class SelectedResourceCategory extends Notifier<ResourceCategory> {
  @override
  ResourceCategory build() => ResourceCategory.all;

  void select(ResourceCategory category) => state = category;
}

final selectedResourceCategoryProvider =
    NotifierProvider<SelectedResourceCategory, ResourceCategory>(
      SelectedResourceCategory.new,
    );

class SelectedExtensionSort extends Notifier<ExtensionSortOption> {
  @override
  ExtensionSortOption build() => ExtensionSortOption.nameAsc;

  void select(ExtensionSortOption option) => state = option;
}

final selectedExtensionSortProvider =
    NotifierProvider<SelectedExtensionSort, ExtensionSortOption>(
      SelectedExtensionSort.new,
    );

/// Curated Top 10 English Tachiyomi/Keiyoushi manga & webtoon extensions.
const List<({String label, List<String> matchTerms})> kTop10ExtensionSpecs = [
  (label: 'MangaDex', matchTerms: ['mangadex']),
  (label: 'Comick', matchTerms: ['comick']),
  (label: 'Weeb Central', matchTerms: ['weeb central', 'weebcentral']),
  (label: 'MangaFire', matchTerms: ['mangafire']),
  (label: 'Bato.to', matchTerms: ['bato.to', 'batoto']),
  (label: 'Asura Scans', matchTerms: ['asura']),
  (label: 'Flame Comics', matchTerms: ['flame comics', 'flamescans']),
  (label: 'Mangakakalot', matchTerms: ['mangakakalot', 'manganato']),
  (label: 'Webtoon', matchTerms: ['webtoon']),
  (label: 'ReadComicsOnline', matchTerms: ['readcomicsonline', 'batcave']),
];

/// Curated Top Video & Anime extensions from Yuzono / Mangayomi stores.
const List<({String label, List<String> matchTerms})> kTopVideoExtensionSpecs = [
  (label: 'HiAnime', matchTerms: ['hianime', 'zoro']),
  (label: 'Gogoanime', matchTerms: ['gogoanime']),
  (label: 'AnimePahe', matchTerms: ['animepahe']),
  (label: 'AniWave', matchTerms: ['aniwave', '9anime']),
  (label: 'Crunchyroll', matchTerms: ['crunchyroll']),
  (label: 'Bilibili', matchTerms: ['bilibili']),
  (label: 'KickAssAnime', matchTerms: ['kickassanime']),
  (label: 'Miruro', matchTerms: ['miruro', 'allanime']),
  (label: 'AnimeKai', matchTerms: ['animekai', 'kaido']),
  (label: 'Dailymotion', matchTerms: ['dailymotion', 'donghua']),
];

/// Curated Top Novel & Book extensions from Mangayomi / LNReader stores.
const List<({String label, List<String> matchTerms})> kTopNovelExtensionSpecs = [
  (label: 'RoyalRoad', matchTerms: ['royalroad']),
  (label: 'Web Novel Translations', matchTerms: ['webnoveltranslations']),
  (label: 'bookReadFree', matchTerms: ['bookreadfree']),
  (label: 'LightNovelPub', matchTerms: ['lightnovelpub', 'novelpub']),
  (label: 'FreeWebNovel', matchTerms: ['freewebnovel']),
  (label: 'BoxNovel', matchTerms: ['boxnovel']),
  (label: 'WuxiaWorld', matchTerms: ['wuxiaworld']),
  (label: 'ScribbleHub', matchTerms: ['scribblehub']),
  (label: 'ReadLightNovel', matchTerms: ['readlightnovel', 'novelfull']),
  (label: 'ArNovel', matchTerms: ['arnovel', 'kolnovel']),
];

bool _matchesEnabledLangs(Extension e, Set<String>? enabledLanguages) {
  final lang = (e.language?.code ?? e.lang).trim().toLowerCase();
  if (!isAllowedContentLanguage(lang)) return false;
  if (enabledLanguages == null) {
    return lang == 'en' || lang == 'ar' || lang == 'all';
  }
  final contentLangs = {
    for (final c in enabledLanguages)
      if (c != 'installed' && c != 'update' && isAllowedContentLanguage(c))
        c.toLowerCase(),
  };
  if (contentLangs.isEmpty) return false;
  return contentLangs.contains(lang);
}

/// Selects up to one matching extension per curated Top 10 entry,
/// respecting [enabledLanguages] when provided.
List<Extension> selectTop10Extensions(
  Iterable<Extension> extensions, {
  Set<String>? enabledLanguages,
}) {
  final pool = extensions
      .where(
        (e) =>
            !isVideoExtension(e) &&
            !isNovelExtension(e) &&
            _matchesEnabledLangs(e, enabledLanguages),
      )
      .toList();
  final picked = _pickMatchingExtensions(pool, kTop10ExtensionSpecs);
  if (picked.length >= 6) return picked;
  final seen = {for (final e in picked) e.pkgName};
  for (final ext in pool) {
    if (seen.add(ext.pkgName)) {
      picked.add(ext);
      if (picked.length >= 10) break;
    }
  }
  return picked;
}

/// Video extensions have been removed; always returns an empty list.
List<Extension> selectTopVideoExtensions(
  Iterable<Extension> extensions, {
  Set<String>? enabledLanguages,
}) => const <Extension>[];

/// Selects top Novel & Book extensions that install as real sources.
List<Extension> selectTopNovelExtensions(
  Iterable<Extension> extensions, {
  Set<String>? enabledLanguages,
}) {
  final novelPool = extensions
      .where(
        (e) => isNovelExtension(e) && _matchesEnabledLangs(e, enabledLanguages),
      )
      .toList();
  if (novelPool.isEmpty) return const <Extension>[];
  final picked = _pickMatchingExtensions(
    novelPool,
    kTopNovelExtensionSpecs,
  );
  if (picked.length >= 6) return picked;
  final seen = {for (final e in picked) e.pkgName};
  for (final ext in novelPool) {
    if (seen.add(ext.pkgName)) {
      picked.add(ext);
      if (picked.length >= 10) break;
    }
  }
  return picked;
}

List<Extension> _pickMatchingExtensions(
  List<Extension> pool,
  List<({String label, List<String> matchTerms})> specs,
) {
  final picked = <Extension>[];
  final seenPkg = <String>{};

  for (final spec in specs) {
    Extension? match;
    for (final term in spec.matchTerms) {
      final needle = term.toLowerCase();
      for (final ext in pool) {
        if (seenPkg.contains(ext.pkgName)) continue;
        final name = ext.name.toLowerCase();
        final pkg = ext.pkgName.toLowerCase();
        if (name.contains(needle) || pkg.contains(needle)) {
          match = ext;
          break;
        }
      }
      if (match != null) break;
    }
    if (match != null) {
      seenPkg.add(match.pkgName);
      picked.add(match);
    }
  }
  return picked;
}
