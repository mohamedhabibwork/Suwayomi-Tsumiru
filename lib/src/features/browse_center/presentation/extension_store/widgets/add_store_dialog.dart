// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../graphql/__generated__/schema.graphql.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/network/graphql_errors.dart';
import '../../../../../widgets/popup_widgets/pop_button.dart';
import '../../../../account/data/account_providers.dart';
import '../../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../../data/extension_store_repository/extension_store_repository.dart';
import '../../../domain/extension/top_extensions.dart';

/// Duplicate URLs use exact string equality, as required by the server.
class AddStoreDialog extends HookConsumerWidget {
  const AddStoreDialog({super.key, required this.existingUrls});

  final Set<String> existingUrls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final url = useState('');
    final submitting = useState(false);
    final serverError = useState<String?>(null);

    final trimmed = url.value.trim();
    final isDuplicate =
        existingUrls.contains(trimmed) ||
        (trimmed.isNotEmpty &&
            isExtensionStoreUrlPresent(trimmed, existingUrls));
    final canManage = ref
        .watch(settledAccountAccessProvider)
        .allows(Enum$UserPermission.MANAGE_EXTENSION_STORES);
    final canSubmit =
        canManage && trimmed.isNotEmpty && !isDuplicate && !submitting.value;

    Future<void> submit() async {
      submitting.value = true;
      serverError.value = null;
      try {
        await ref.read(extensionStoreRepositoryProvider).addStore(trimmed);
        if (context.mounted) {
          // ignore: unused_result
          ref.refresh(extensionStoreListProvider.future);
          Navigator.pop(context);
        }
      } catch (e) {
        if (!context.mounted) return;
        // Server exceptions can contain HTML or stack traces; show only a clamped first line.
        final firstLine = isPermissionDenied(e)
            ? context.l10n.accountPermissionDenied
            : e.toString().split('\n').first;
        submitting.value = false;
        serverError.value = firstLine.length > 200
            ? firstLine.substring(0, 200)
            : firstLine;
      }
    }

    return AlertDialog(
      title: Text(context.l10n.addExtensionStore),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            maxLines: 1,
            onChanged: (value) {
              url.value = value;
              if (serverError.value != null) serverError.value = null;
            },
            decoration: InputDecoration(
              labelText: context.l10n.storeIndexUrl,
              errorText: isDuplicate
                  ? context.l10n.extensionStoreAlreadyExists
                  : serverError.value,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in kCuratedExtensionStores)
                if (!isExtensionStoreUrlPresent(
                      preset.indexUrl,
                      existingUrls,
                    ) &&
                    (ref.watch(showNSFWProvider).ifNull(false) ||
                        !preset.isNsfw))
                  ActionChip(
                    label: Text(preset.name),
                    onPressed: submitting.value
                        ? null
                        : () {
                            controller.text = preset.indexUrl;
                            url.value = preset.indexUrl;
                            if (serverError.value != null) {
                              serverError.value = null;
                            }
                          },
                  ),
            ],
          ),
        ],
      ),
      actions: [
        const PopButton(),
        ElevatedButton(
          onPressed: canSubmit ? submit : null,
          child: Text(
            submitting.value ? context.l10n.processing : context.l10n.add,
          ),
        ),
      ],
    );
  }
}
