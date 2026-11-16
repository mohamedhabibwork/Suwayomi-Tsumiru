// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'extension_model.dart';

/// Official Keiyoushi extension repository index URL (Protobuf).
const kKeiyoushiStoreUrl =
    'https://github.com/keiyoushi/extensions/raw/repo/index.pb';

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
