// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import '../../../graphql/__generated__/schema.graphql.dart';

/// Unknown ratings fail closed when adult content is disabled.
bool isNsfwFromWarning(Enum$ContentWarning warning) => switch (warning) {
      Enum$ContentWarning.SAFE => false,
      Enum$ContentWarning.MIXED || Enum$ContentWarning.NSFW => true,
      _ => true,
    };

// Match whole tags; "mature" denotes dark themes and is not treated as adult content.
const _adultTags = {
  'hentai',
  'adult',
  'smut',
  'lewd',
  'nsfw',
  'erotica',
  'pornographic',
  '18+',
  '+18',
  'ecchi',
  'هنتاي',
  'سكس',
  'للكبار',
  'إيتشي',
};

const _adultTextKeywords = [
  '18+',
  '+18',
  'nsfw',
  'hentai',
  'pornhub',
  'xnxx',
  'xvideos',
  'hanime',
  'erotica',
  'pornographic',
  'هنتاي',
  'سكس',
  'للكبار',
];

bool hasAdultTag(Iterable<String> genre) =>
    genre.any((tag) => _adultTags.contains(tag.trim().toLowerCase()));

bool hasAdultKeywordText(String? text) {
  if (text == null || text.isEmpty) return false;
  final lower = text.toLowerCase();
  for (final kw in _adultTextKeywords) {
    if (lower.contains(kw)) return true;
  }
  return false;
}

/// Checks genre tags, optional user tags, title/source keywords, and source content warning.
bool isAdultManga(
  Enum$ContentWarning? warning,
  Iterable<String> genre, {
  Iterable<String>? userTags,
  String? title,
  String? sourceName,
}) {
  if (hasAdultTag(genre)) return true;
  if (userTags != null && hasAdultTag(userTags)) return true;
  if (hasAdultKeywordText(title) || hasAdultKeywordText(sourceName)) {
    return true;
  }
  return switch (warning) {
    Enum$ContentWarning.SAFE => false,
    Enum$ContentWarning.MIXED => false,
    Enum$ContentWarning.NSFW => true,
    null => false,
    _ => true,
  };
}
