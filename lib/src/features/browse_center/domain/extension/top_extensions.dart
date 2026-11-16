// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/db_keys.dart';
import '../../../../utils/mixin/shared_preferences_client_mixin.dart';
import 'extension_model.dart';

/// Official Keiyoushi extension repository index URL (Protobuf).
const kKeiyoushiStoreUrl =
    'https://github.com/keiyoushi/extensions/raw/repo/index.pb';

/// Yuzono multi-source Manga & Comics extension store.
const kYuzonoMangaStoreUrl =
    'https://raw.githubusercontent.com/yuzono/manga-repo/repo/index.min.json';

/// Kohi-den Anime & Video extension store.
const kKohidenVideoStoreUrl =
    'https://raw.githubusercontent.com/kohiden/extensions/main/index.min.json';

/// Yuzono Anime & Video extension store.
const kYuzonoVideoStoreUrl =
    'https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json';

/// Suwayomi community extension store.
const kSuwayomiStoreUrl =
    'https://raw.githubusercontent.com/Suwayomi/tachiyomi-extension/repo/index.min.json';

class CuratedStoreSpec {
  const CuratedStoreSpec({
    required this.name,
    required this.subtitle,
    required this.indexUrl,
    required this.category,
    this.isDefault = false,
  });

  final String name;
  final String subtitle;
  final String indexUrl;
  final ResourceCategory category;
  final bool isDefault;
}

const List<CuratedStoreSpec> kCuratedExtensionStores = [
  CuratedStoreSpec(
    name: 'Keiyoushi Official Store (Default)',
    subtitle: 'Top Manga, Manhwa, Manhua & Webtoon extensions',
    indexUrl: kKeiyoushiStoreUrl,
    category: ResourceCategory.manga,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Yuzono Multi-Resource Store (Default)',
    subtitle: 'Manga, Western Comics & Global reading sources',
    indexUrl: kYuzonoMangaStoreUrl,
    category: ResourceCategory.comics,
    isDefault: true,
  ),
  CuratedStoreSpec(
    name: 'Kohi-den Video & Anime Store',
    subtitle: 'Anime & Video streaming extension repository',
    indexUrl: kKohidenVideoStoreUrl,
    category: ResourceCategory.videos,
  ),
  CuratedStoreSpec(
    name: 'Yuzono Anime & Video Store',
    subtitle: 'Multi-language Anime, Donghua & Video sources',
    indexUrl: kYuzonoVideoStoreUrl,
    category: ResourceCategory.videos,
  ),
  CuratedStoreSpec(
    name: 'Suwayomi Community Store',
    subtitle: 'Community-maintained Tachiyomi & Suwayomi sources',
    indexUrl: kSuwayomiStoreUrl,
    category: ResourceCategory.other,
  ),
];

enum ResourceCategory {
  all('All Resources'),
  manga('Manga & Webtoons'),
  videos('Videos & Anime'),
  comics('Comics & Graphic Novels'),
  other('Novels & Else');

  const ResourceCategory(this.label);
  final String label;
}

class MediaResourceItem {
  const MediaResourceItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.url,
    required this.category,
    this.lang = 'EN / Multi',
    this.isDefault = false,
    this.isNsfw = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final String url;
  final ResourceCategory category;
  final String lang;
  final bool isDefault;
  final bool isNsfw;
}

const List<MediaResourceItem> kMediaResourceCatalog = [
  // Videos & Anime
  MediaResourceItem(
    id: 'video_hianime',
    name: 'HiAnime (Video & Anime)',
    subtitle: 'HD Sub & Dub anime episodes, movies & simulcasts',
    url: 'https://hianime.to',
    category: ResourceCategory.videos,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'video_miruro',
    name: 'Miruro TV (Multi-Server Video)',
    subtitle: 'Multi-source anime & video streaming with AniList sync',
    url: 'https://www.miruro.tv',
    category: ResourceCategory.videos,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'video_animepahe',
    name: 'AnimePahe (Fast Video)',
    subtitle: 'Lightweight, fast-loading anime video episodes',
    url: 'https://animepahe.ru',
    category: ResourceCategory.videos,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'video_crunchyroll',
    name: 'Crunchyroll (Official Video)',
    subtitle: 'Official simulcast anime, movies & video library',
    url: 'https://www.crunchyroll.com',
    category: ResourceCategory.videos,
  ),
  MediaResourceItem(
    id: 'video_bilibili',
    name: 'Bilibili TV (Anime & Creator Videos)',
    subtitle: 'Official Donghua, anime series & community videos',
    url: 'https://www.bilibili.tv/en/anime',
    category: ResourceCategory.videos,
  ),
  MediaResourceItem(
    id: 'video_aniwave',
    name: 'AniWave / 9Anime (Video)',
    subtitle: 'Full anime catalog with sub, dub & special episodes',
    url: 'https://aniwave.se',
    category: ResourceCategory.videos,
  ),
  MediaResourceItem(
    id: 'video_gogoanime',
    name: 'GoGoAnime (Classic & Ongoing Video)',
    subtitle: 'Large archive of classic and ongoing anime videos',
    url: 'https://anitaku.pe',
    category: ResourceCategory.videos,
  ),
  MediaResourceItem(
    id: 'video_kickassanime',
    name: 'KickAssAnime (High-Bitrate Video)',
    subtitle: '1080p/4K anime video streaming & seasonal releases',
    url: 'https://kickassanime.mx',
    category: ResourceCategory.videos,
  ),
  MediaResourceItem(
    id: 'video_museasia',
    name: 'Muse Asia & Official Anime Video',
    subtitle: 'Free licensed full-episode anime playlists',
    url: 'https://www.youtube.com/@MuseAsia/playlists',
    category: ResourceCategory.videos,
  ),
  MediaResourceItem(
    id: 'video_hanime_nsfw',
    name: 'Hanime.tv (18+ Adult Video)',
    subtitle: '18+ NSFW anime video streaming (Requires Face ID unlock)',
    url: 'https://hanime.tv',
    category: ResourceCategory.videos,
    isNsfw: true,
  ),

  // Comics & Graphic Novels
  MediaResourceItem(
    id: 'comic_webtoon',
    name: 'LINE Webtoon (Originals & Canvas)',
    subtitle: 'Official vertical-scroll webtoons, romance, action & fantasy',
    url: 'https://www.webtoons.com/en/',
    category: ResourceCategory.comics,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'comic_readcomics',
    name: 'ReadComicsOnline (Western Comics)',
    subtitle: 'Marvel, DC, Image, Dark Horse & indie comic issues',
    url: 'https://readcomiconline.li',
    category: ResourceCategory.comics,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'comic_tapas',
    name: 'Tapas (Webcomics & Novels)',
    subtitle: 'Bite-sized webcomics, manhwa & indie graphic stories',
    url: 'https://tapas.io',
    category: ResourceCategory.comics,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'comic_batcave',
    name: 'Batcave Comics',
    subtitle: 'Western comic books, graphic novels & omnibus collections',
    url: 'https://batcave.biz',
    category: ResourceCategory.comics,
  ),
  MediaResourceItem(
    id: 'comic_comicextra',
    name: 'ComicExtra Archive',
    subtitle: 'Full-issue western comics & graphic novel series',
    url: 'https://comicextra.org',
    category: ResourceCategory.comics,
  ),

  // Novels & Else Resources
  MediaResourceItem(
    id: 'other_royalroad',
    name: 'RoyalRoad (Web Novels & LitRPG)',
    subtitle: 'Top progression fantasy, sci-fi & original web novels',
    url: 'https://www.royalroad.com/fictions/best-rated',
    category: ResourceCategory.other,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'other_novelupdates',
    name: 'NovelUpdates (Light Novels)',
    subtitle: 'Directory of translated Japanese, Korean & Chinese novels',
    url: 'https://www.novelupdates.com',
    category: ResourceCategory.other,
    isDefault: true,
  ),
  MediaResourceItem(
    id: 'other_scribblehub',
    name: 'ScribbleHub (Web Fiction)',
    subtitle: 'Original serialized web novels & light fiction',
    url: 'https://www.scribblehub.com',
    category: ResourceCategory.other,
  ),
  MediaResourceItem(
    id: 'other_archive_books',
    name: 'Internet Archive (Manga, Books & Video)',
    subtitle: 'Public domain books, retro comics, artbooks & media archive',
    url: 'https://archive.org/details/manga_library',
    category: ResourceCategory.other,
  ),
  MediaResourceItem(
    id: 'other_bookwalker',
    name: 'BookWalker Global (Light Novels & Manga)',
    subtitle: 'Official English light novels, simulpubs & free previews',
    url: 'https://global.bookwalker.jp',
    category: ResourceCategory.other,
  ),
];

class SelectedMediaResources extends Notifier<List<String>?>
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.selectedMediaResources);

  bool isSelected(String id) =>
      (state ?? (DBKeys.selectedMediaResources.initial as List<String>))
          .contains(id);

  void toggle(String id) {
    final current = [
      ...(state ?? (DBKeys.selectedMediaResources.initial as List<String>)),
    ];
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    update(current);
  }

  void selectDefaults() {
    update([
      for (final item in kMediaResourceCatalog)
        if (item.isDefault && !item.isNsfw) item.id,
    ]);
  }

  void selectAll({required bool includeNsfw}) {
    update([
      for (final item in kMediaResourceCatalog)
        if (includeNsfw || !item.isNsfw) item.id,
    ]);
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

/// Selects up to one matching extension per curated Top 10 entry,
/// preferring English (`en`) or multi-language (`all`) extensions.
List<Extension> selectTop10Extensions(Iterable<Extension> extensions) {
  final pool = extensions
      .where((e) => e.lang == 'en' || e.lang == 'all')
      .toList();
  final picked = <Extension>[];
  final seenPkg = <String>{};

  for (final spec in kTop10ExtensionSpecs) {
    Extension? match;
    for (final term in spec.matchTerms) {
      for (final ext in pool) {
        if (seenPkg.contains(ext.pkgName)) continue;
        final name = ext.name.toLowerCase();
        final pkg = ext.pkgName.toLowerCase();
        if (name.contains(term) || pkg.contains(term)) {
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
