// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import '../../features/browse_center/domain/source/source_model.dart';
import '../../features/manga_book/domain/chapter/chapter_model.dart';
import '../../features/manga_book/domain/manga/manga_model.dart';

/// Determines whether a [SourceDto] represents a Video / Anime streaming source.
bool isVideoStreamingSource(SourceDto? source) {
  if (source == null) return false;
  final name = source.name.toLowerCase();
  final display = source.displayName.toLowerCase();
  final pkg = source.$extension.pkgName.toLowerCase();
  if (pkg.contains('.novelextension.') ||
      name.contains('(novel)') ||
      display.contains('(novel)')) {
    return false;
  }
  return pkg.contains('.animeextension.') ||
      name.contains('(video)') ||
      display.contains('(video)') ||
      name.contains('aniyomi:');
}

/// Determines whether a [MangaDto] (and optionally a [ChapterDto]) is a Video / Anime entry.
bool isVideoStreamingManga(MangaDto? manga, [ChapterDto? chapter]) {
  if (manga == null) return false;
  final sourceName =
      (manga.source?.name ?? manga.source?.displayName ?? '').toLowerCase();
  if (sourceName.contains('(novel)')) return false;
  if (sourceName.contains('(video)')) return true;
  if (manga.url.toLowerCase().startsWith('/anime/')) return true;
  if (manga.genre.any((g) {
    final lower = g.trim().toLowerCase();
    return lower == 'video';
  })) {
    return true;
  }
  if (chapter != null &&
      chapter.name.trim().toLowerCase().startsWith('episode')) {
    return true;
  }
  return false;
}

/// Known base URLs for popular video/anime sources when [homeUrl] is not populated on the source.
String? inferVideoProviderBaseUrl(String? sourceName) {
  if (sourceName == null || sourceName.trim().isEmpty) return null;
  final lower = sourceName
      .toLowerCase()
      .replaceAll('(video)', '')
      .replaceAll('aniyomi:', '')
      .trim();
  if (lower.contains('hianime') || lower.contains('zoro')) {
    return 'https://hianime.to';
  }
  if (lower.contains('gogoanime') || lower.contains('anitaku')) {
    return 'https://anitaku.bz';
  }
  if (lower.contains('animepahe')) {
    return 'https://animepahe.ru';
  }
  if (lower.contains('miruro')) {
    return 'https://www.miruro.tv';
  }
  if (lower.contains('allanime')) {
    return 'https://allmanga.to';
  }
  if (lower.contains('kaido')) {
    return 'https://kaido.to';
  }
  if (lower.contains('animekai') || lower.contains('anikai')) {
    return 'https://animekai.to';
  }
  if (lower.contains('aniwave') || lower.contains('9anime')) {
    return 'https://9animetv.to';
  }
  if (lower.contains('kickassanime')) {
    return 'https://kaa.mx';
  }
  if (lower.contains('crunchyroll')) {
    return 'https://www.crunchyroll.com';
  }
  if (lower.contains('bilibili')) {
    return 'https://www.bilibili.tv/en';
  }
  if (lower.contains('dailymotion')) {
    return 'https://www.dailymotion.com';
  }
  if (lower.contains('franime')) {
    return 'https://franime.fr';
  }
  if (lower.contains('otakufr')) {
    return 'https://otakufr.cc';
  }
  if (lower.contains('animesultra')) {
    return 'https://w2.animesultra.net';
  }
  if (lower.contains('okanime')) {
    return 'https://www.okanime.xyz';
  }
  if (lower.contains('witanime') || lower.contains('wit anime')) {
    return 'https://witanime.cyou';
  }
  if (lower.contains('anime4up')) {
    return 'https://anime4up.rest';
  }
  if (lower.contains('aniworld')) {
    return 'https://aniworld.to';
  }
  if (lower.contains('animeflv')) {
    return 'https://www3.animeflv.net';
  }
  if (lower.contains('jkanime')) {
    return 'https://jkanime.net';
  }
  if (lower.contains('monoschinos')) {
    return 'https://monoschinos2.com';
  }
  if (lower.contains('otakudesu')) {
    return 'https://otakudesu.cloud';
  }
  if (lower.contains('kuramanime')) {
    return 'https://kuramanime.red';
  }
  if (lower.contains('samehadaku')) {
    return 'https://samehadaku.email';
  }
  if (lower.contains('animeunity')) {
    return 'https://www.animeunity.so';
  }
  if (lower.contains('animesaturn')) {
    return 'https://www.animesaturn.cx';
  }
  if (lower.contains('hanime')) {
    return 'https://hanime.tv';
  }
  if (lower.contains('hentaihaven')) {
    return 'https://hentaihaven.xxx';
  }
  if (lower.contains('muchohentai')) {
    return 'https://muchohentai.com';
  }
  return null;
}

/// Builds a direct provider search or watch URL for a given base site and query.
String buildProviderVideoUrl({
  required String baseUrl,
  String? query,
}) {
  var base = baseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  if (query == null || query.trim().isEmpty) return base;
  final q = Uri.encodeQueryComponent(query.trim());
  final host = (Uri.tryParse(base)?.host ?? base).toLowerCase();

  if (host.contains('hianime') ||
      host.contains('kaido') ||
      host.contains('zoroto') ||
      host.contains('9animetv') ||
      host.contains('aniwatch')) {
    return '$base/search?keyword=$q';
  }
  if (host.contains('anitaku') || host.contains('gogoanime')) {
    return '$base/search.html?keyword=$q';
  }
  if (host.contains('miruro')) {
    return '$base/search?query=$q';
  }
  if (host.contains('animekai') || host.contains('anikai')) {
    return '$base/browser?keyword=$q';
  }
  if (host.contains('crunchyroll')) {
    return '$base/search?q=$q';
  }
  if (host.contains('bilibili')) {
    return '$base/search-result?q=$q';
  }
  if (host.contains('dailymotion')) {
    return '$base/search/$q/videos';
  }
  if (host.contains('animeflv')) {
    return '$base/browse?q=$q';
  }
  if (host.contains('jkanime')) {
    return '$base/buscar/$q/1/';
  }
  if (host.contains('okanime')) {
    return '$base/search/?s=$q';
  }
  if (host.contains('witanime') ||
      host.contains('anime4up') ||
      host.contains('otakudesu') ||
      host.contains('samehadaku')) {
    return '$base/?s=$q';
  }
  if (host.contains('hanime')) {
    return 'https://hanime.tv/browse/images?q=$q';
  }
  return '$base/search?keyword=$q&q=$q&s=$q';
}

/// Resolves the best live streaming URL for a video series or episode.
String resolveVideoStreamUrl({
  MangaDto? manga,
  ChapterDto? chapter,
  SourceDto? source,
}) {
  // 1. Check if chapter.realUrl is a valid external HTTP(S) URL (not a synthetic/local URL).
  final chapterReal = chapter?.realUrl?.trim();
  if (chapterReal != null &&
      chapterReal.startsWith('http') &&
      !chapterReal.contains('synthetic.suwayomi.local') &&
      !chapterReal.contains('/anime/') &&
      !chapterReal.contains('/novel/')) {
    return chapterReal;
  }

  // 2. Check if manga.realUrl is a valid external HTTP(S) URL.
  final mangaReal = manga?.realUrl?.trim();
  if (mangaReal != null &&
      mangaReal.startsWith('http') &&
      !mangaReal.contains('synthetic.suwayomi.local') &&
      !mangaReal.contains('/anime/') &&
      !mangaReal.contains('/novel/')) {
    if (chapter == null) return mangaReal;
  }

  // 3. Resolve provider baseUrl from source.homeUrl or source name mapping.
  final sourceHome = source?.homeUrl?.trim();
  final sourceName =
      source?.name ?? manga?.source?.name ?? manga?.source?.displayName;
  final providerBase =
      (sourceHome != null &&
          sourceHome.startsWith('http') &&
          !sourceHome.contains('github.com/m2k3a'))
      ? sourceHome
      : inferVideoProviderBaseUrl(sourceName) ?? 'https://hianime.to';

  final title = manga?.title.trim() ?? '';
  final epName = chapter?.name.trim() ?? '';
  final searchQuery = [
    if (title.isNotEmpty) title,
    if (epName.isNotEmpty && !title.toLowerCase().contains(epName.toLowerCase()))
      epName,
  ].join(' ');

  return buildProviderVideoUrl(
    baseUrl: providerBase,
    query: searchQuery.isNotEmpty ? searchQuery : null,
  );
}

/// Resolves the live homepage or search URL for a Video [SourceDto].
String resolveSourceVideoPortalUrl(SourceDto source, {String? query}) {
  final home = source.homeUrl?.trim();
  final base =
      (home != null &&
          home.startsWith('http') &&
          !home.contains('github.com/m2k3a'))
      ? home
      : inferVideoProviderBaseUrl(source.name) ?? 'https://hianime.to';
  return buildProviderVideoUrl(baseUrl: base, query: query);
}

/// Alternate streaming mirrors so the user can switch servers if a mirror is blocked in their region.
List<({String name, String url})> buildVideoStreamMirrors({
  MangaDto? manga,
  ChapterDto? chapter,
  SourceDto? source,
}) {
  final primaryUrl = resolveVideoStreamUrl(
    manga: manga,
    chapter: chapter,
    source: source,
  );
  final sourceLabel =
      (source?.name ?? manga?.source?.name ?? 'Primary Server')
          .replaceAll('(Video)', '')
          .trim();
  final title = manga?.title.trim() ?? '';
  final epName = chapter?.name.trim() ?? '';
  final fullQuery = [
    if (title.isNotEmpty) title,
    if (epName.isNotEmpty) epName,
  ].join(' ');

  final mirrors = <({String name, String url})>[
    (
      name: sourceLabel.isEmpty ? 'Primary Stream' : '$sourceLabel (Source)',
      url: primaryUrl,
    ),
    (
      name: 'Miruro HD',
      url: buildProviderVideoUrl(
        baseUrl: 'https://www.miruro.tv',
        query: title.isNotEmpty ? title : fullQuery,
      ),
    ),
    (
      name: 'HiAnime',
      url: buildProviderVideoUrl(
        baseUrl: 'https://hianime.to',
        query: title.isNotEmpty ? title : fullQuery,
      ),
    ),
    (
      name: 'AnimeKai',
      url: buildProviderVideoUrl(
        baseUrl: 'https://animekai.to',
        query: title.isNotEmpty ? title : fullQuery,
      ),
    ),
    (
      name: 'Gogoanime',
      url: buildProviderVideoUrl(
        baseUrl: 'https://anitaku.bz',
        query: title.isNotEmpty ? title : fullQuery,
      ),
    ),
    (
      name: 'Bilibili TV',
      url: buildProviderVideoUrl(
        baseUrl: 'https://www.bilibili.tv/en',
        query: fullQuery,
      ),
    ),
  ];

  final seen = <String>{};
  return [
    for (final m in mirrors)
      if (seen.add(m.url)) m,
  ];
}
