// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/db_keys.dart';
import '../constants/enum.dart';
import '../features/account/data/account_actions.dart';
import '../features/account/presentation/account_code_dialog.dart';
import '../features/auth/presentation/face_id_auth_service.dart';
import '../features/settings/presentation/server/widget/client/server_url_tile/server_url_tile.dart';
import '../features/settings/presentation/server/widget/credential_popup/login_credentials_popup.dart';
import '../routes/router_config.dart';
import '../utils/extensions/custom_extensions.dart';
import '../utils/misc/toast/toast.dart';
import '../utils/motion/reduce_motion.dart';
import 'emoticons.dart';
import 'server_unreachable_view.dart';

class ServerUnauthorizedView extends ConsumerWidget {
  const ServerUnauthorizedView({
    super.key,
    required this.message,
    this.onRetry,
    this.offlineEscape = false,
  });

  /// The server's own wording, kept so a permission denial still reads as one.
  final String message;
  final VoidCallback? onRetry;
  final bool offlineEscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webAuthBlocked = ref.watch(webAuthBlockedProvider);
    final serverUrl =
        ref.watch(serverExternalUrlProvider) ?? DBKeys.serverUrl.initial;
    final cleanMessage = message.contains('\n') &&
            message.contains('suwayomi.tachidesk')
        ? message.split('\n').first.trim()
        : message;
    return Emoticons(
      iconData: FluentIcons.lock_closed_24_regular,
      title: context.l10n.serverSignedOutTitle,
      subTitle: webAuthBlocked
          ? context.l10n.webUnsupportedAuthMode
          : cleanMessage,
      button: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            serverUrl,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              final toast = ref.read(toastProvider);
              try {
                final user = await signInOrRegisterWithFaceId(
                  ref,
                  serverBaseUrl: serverUrl,
                );
                toast?.show('Signed in with Face ID as $user');
              } catch (e) {
                toast?.showError(e.toString());
              }
            },
            icon: const Icon(FluentIcons.person_passkey_24_regular),
            label: const Text('Sign in with Face ID'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AccountCodeDialog(
                    mode: AccountCodeMode.registration,
                    onSubmit: ref.read(accountActionsProvider).redeemCode,
                  ),
                  animationStyle: context.motionStyle,
                ),
                icon: const Icon(FluentIcons.person_add_24_regular),
                label: Text(context.l10n.accountRegistrationTitle),
              ),
              FilledButton.tonalIcon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const LoginCredentialsPopup(
                    authType: AuthType.uiLogin,
                    allowModeSelection: true,
                  ),
                  animationStyle: context.motionStyle,
                ),
                icon: const Icon(FluentIcons.arrow_enter_20_regular),
                label: Text(context.l10n.onboardingSignIn),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => const ConnectionRoute().push(context),
            icon: const Icon(FluentIcons.plug_connected_24_regular),
            label: Text(context.l10n.serverUnreachableAction),
          ),
          if (offlineEscape) const ViewOfflineButton(),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(context.l10n.refresh)),
        ],
      ),
    );
  }
}
