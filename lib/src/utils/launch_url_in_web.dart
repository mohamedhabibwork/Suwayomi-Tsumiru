// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'extensions/custom_extensions.dart';
import 'misc/toast/toast.dart';

Future<void> launchUrlInWeb(
  BuildContext context,
  String url, [
  Toast? toast,
  String? failureMessage,
]) async {
  final uri = Uri.tryParse(url);
  // Restrict to http(s): these URLs come from server/source data, and a
  // malicious source could otherwise trigger arbitrary intents (intent://, tel:, etc).
  final scheme = uri?.scheme.toLowerCase();
  final launched =
      uri != null &&
      (scheme == 'http' || scheme == 'https') &&
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: "_blank",
      );
  if (!launched) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      toast?.showError(failureMessage ?? context.l10n.errorLaunchURL(url));
    }
  }
}

/// Opens an http/https resource in the embedded in-app browser (SFSafariViewController on iOS)
/// with full HTML5 video & media playback, falling back to external browser if unsupported.
Future<void> launchUrlInAppBrowser(
  BuildContext context,
  String url, [
  Toast? toast,
  String? failureMessage,
]) async {
  final uri = Uri.tryParse(url);
  final scheme = uri?.scheme.toLowerCase();
  if (uri == null || (scheme != 'http' && scheme != 'https')) {
    if (context.mounted) {
      toast?.showError(failureMessage ?? context.l10n.errorLaunchURL(url));
    }
    return;
  }
  bool launched = false;
  try {
    launched = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
      webOnlyWindowName: "_blank",
    );
  } catch (_) {
    launched = false;
  }
  if (!launched) {
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: "_blank",
      );
    } catch (_) {
      launched = false;
    }
  }
  if (!launched) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      toast?.showError(failureMessage ?? context.l10n.errorLaunchURL(url));
    }
  }
}
