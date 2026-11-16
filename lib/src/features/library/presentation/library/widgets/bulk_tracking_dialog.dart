// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/misc/toast/toast.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../../tracking/data/tracker_repository.dart';

class BulkTrackingDialog extends HookConsumerWidget {
  const BulkTrackingDialog({super.key, required this.mangas});

  final List<MangaDto> mangas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersProvider);
    final selectedTrackerIds = useState<Set<int>>({});
    final isSubmitting = useState(false);

    return AlertDialog(
      title: Text('Track ${mangas.length} Series'),
      content: SizedBox(
        width: 360,
        child: trackersAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(e.toString()),
          data: (trackers) {
            final loggedIn = trackers.where((t) => t.isLoggedIn).toList();
            if (loggedIn.isEmpty) {
              return const Text(
                'No tracking services logged in. Sign in under Settings → Tracking first.',
              );
            }
            if (selectedTrackerIds.value.isEmpty && !isSubmitting.value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted && selectedTrackerIds.value.isEmpty) {
                  selectedTrackerIds.value = {loggedIn.first.id};
                }
              });
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automatically search and bind the top match on selected trackers:',
                ),
                const SizedBox(height: 8),
                for (final tracker in loggedIn)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selectedTrackerIds.value.contains(tracker.id),
                    title: Text(tracker.name),
                    onChanged: isSubmitting.value
                        ? null
                        : (checked) {
                            final next = {...selectedTrackerIds.value};
                            if (checked == true) {
                              next.add(tracker.id);
                            } else {
                              next.remove(tracker.id);
                            }
                            selectedTrackerIds.value = next;
                          },
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting.value
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: isSubmitting.value || selectedTrackerIds.value.isEmpty
              ? null
              : () async {
                  isSubmitting.value = true;
                  final repo = ref.read(trackerRepositoryProvider);
                  var boundCount = 0;
                  for (final manga in mangas) {
                    for (final trackerId in selectedTrackerIds.value) {
                      try {
                        final matches = await repo.search(
                          trackerId: trackerId,
                          query: manga.title,
                        );
                        final top = matches?.firstOrNull;
                        if (top != null) {
                          await repo.bind(
                            mangaId: manga.id,
                            trackerId: trackerId,
                            remoteId: top.remoteId,
                            private: false,
                          );
                          boundCount++;
                        }
                      } catch (_) {}
                    }
                  }
                  if (!context.mounted) return;
                  ref
                      .read(toastProvider)
                      ?.show('Bound $boundCount tracker records');
                  Navigator.of(context).pop();
                },
          child: isSubmitting.value
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Bind Selected'),
        ),
      ],
    );
  }
}
