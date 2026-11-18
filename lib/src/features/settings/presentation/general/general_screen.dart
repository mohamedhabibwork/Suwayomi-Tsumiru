// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../routes/router_config.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/platform/platform_runtime.dart';
import '../../../../widgets/desktop/desktop_page_frame.dart';
import '../../../../widgets/desktop/desktop_top_bar.dart';
import '../../../../widgets/shell/detail_navigation_shell_screen.dart';
import '../../search/settings_search_registry.dart';
import '../../widgets/settings_group_card/settings_group_card.dart';
import '../library/widgets/persistent_search_bar/persistent_search_bar.dart';
import '../security/security_settings_provider.dart';
import 'quick_search_toggle/quick_search_toggle_tile.dart';
import 'widgets/force_portrait_tile.dart';

class GeneralScreen extends ConsumerWidget {
  const GeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = GoRouter.maybeOf(
      context,
    )?.state.uri.queryParameters['highlight'];
    if (highlight == 'appLanguage') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          const AppearanceSettingsRoute(highlight: 'appLanguage').go(context);
        }
      });
    }

    const portraitTile = SettingsHighlightTarget(
      id: 'lockToPortrait',
      child: ForcePortraitTile(),
    );
    final topBar = showsMergedTopBar(context);
    final title = Text(context.l10n.general);
    final scaffold = Scaffold(
      appBar: topBar
          ? null
          : AppBar(leading: detailNavigationBackButton(context), title: title),
      body: SettingsHighlightScope(
        child: Center(
          child: ConstrainedBox(
            constraints: settingsPageConstraints(context),
            child: ListView(
              padding: settingsPagePadding(context),
              children: [
                const DesktopPageLeadingGap(16),
                SettingsGroupCard(
                  children: [
                    if (canForcePortrait(
                      MediaQuery.sizeOf(context).shortestSide,
                    ))
                      portraitTile,
                    const SettingsHighlightTarget(
                      id: 'persistentSearchBar',
                      child: PersistentSearchBarTile(),
                    ),
                    // Quick search requires a keyboard shortcut to open.
                    if (isKeyboardRuntime)
                      const SettingsHighlightTarget(
                        id: 'quickSearch',
                        child: QuickSearchToggleTile(),
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.screenshot_monitor_rounded),
                      title: const Text(
                        'Black Screen on Screenshot & Recording',
                      ),
                      subtitle: const Text(
                        'Show a black screen when taking screenshots or recording the screen',
                      ),
                      value: ref.watch(blockScreenshotsProvider) ?? true,
                      onChanged: (v) =>
                          ref.read(blockScreenshotsProvider.notifier).update(v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.hide_image_outlined),
                      title: const Text('Do Not Allow Saving Images'),
                      subtitle: const Text(
                        'Prevent saving or copying manga pages and cover images to device gallery',
                      ),
                      value: ref.watch(disableSaveImagesProvider) ?? true,
                      onChanged: (v) => ref
                          .read(disableSaveImagesProvider.notifier)
                          .update(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return titleTopBarSlot(
      topBar: topBar,
      leading: detailNavigationBackButton(context),
      title: title,
      child: scaffold,
    );
  }
}
