// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../graphql/__generated__/schema.graphql.dart';
import '../../../../../utils/analytics/firebase_telemetry_service.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../auth/data/auth_credentials_store.dart';
import '../../../data/extension_repository/extension_repository.dart';
import '../../source/controller/source_controller.dart';
import 'extension_controller.dart';
import 'extension_update_badge.dart';

part 'extension_actions.g.dart';

/// Refreshes sources after extension mutations, which register sources in the same transaction.
class ExtensionActions {
  ExtensionActions(this._ref);

  final Ref _ref;

  ExtensionRepository get _repository => _ref.read(extensionRepositoryProvider);

  Future<void> install(String pkgName, {String? languageCode}) {
    AppTelemetry.logExtensionAction(
      action: 'install',
      pkgName: pkgName,
      language: languageCode,
    );
    return _refreshAfter((current) => _install(pkgName, languageCode, current));
  }

  Future<void> reinstall(String pkgName, {String? languageCode}) {
    AppTelemetry.logExtensionAction(
      action: 'reinstall',
      pkgName: pkgName,
      language: languageCode,
    );
    return _refreshAfter((current) async {
      final repository = _repository;
      repository.permissions.require(Enum$UserPermission.INSTALL_EXTENSIONS);
      repository.permissions.require(
        Enum$UserPermission.UNINSTALL_EXTENSIONS,
      );
      await repository.uninstallExtension(pkgName);
      if (!current()) return;
      await _install(pkgName, languageCode, current);
    });
  }

  Future<void> installFile(BuildContext context, {PlatformFile? file}) {
    AppTelemetry.logExtensionAction(
      action: 'install_file',
      pkgName: file?.name ?? 'local_file',
    );
    return _refreshAfter(
      (_) => _repository.installExtensionFile(context, file: file),
    );
  }

  Future<void> update(String pkgName) {
    AppTelemetry.logExtensionAction(action: 'update', pkgName: pkgName);
    return _refreshAfter((_) => _repository.updateExtension(pkgName));
  }

  Future<void> updateAll(List<String> pkgNames) {
    AppTelemetry.logExtensionAction(
      action: 'update_all',
      pkgName: '${pkgNames.length}_extensions',
    );
    return _refreshAfter((_) => _repository.updateAllExtensions(pkgNames));
  }

  Future<void> uninstall(String pkgName) {
    AppTelemetry.logExtensionAction(action: 'uninstall', pkgName: pkgName);
    return _refreshAfter((_) => _repository.uninstallExtension(pkgName));
  }

  Future<void> _install(
    String pkgName,
    String? languageCode,
    bool Function() current,
  ) async {
    String? resolvedLang = languageCode;
    if (resolvedLang.isBlank) {
      final list = _ref.read(extensionProvider).value;
      final match = list?.where((e) => e.pkgName == pkgName).firstOrNull;
      resolvedLang = match?.lang;
    }
    await _repository.installExtension(pkgName);
    if (!current()) return;
    if (resolvedLang.isNotBlank) _enableSourceLanguage(resolvedLang!);
  }

  // An empty saved filter means all languages were deliberately disabled.
  void _enableSourceLanguage(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final enabled = _ref.read(sourceLanguageFilterProvider);
    final lowerEnabled = {
      for (final c in enabled ?? const <String>[]) c.toLowerCase(),
    };
    if (!lowerEnabled.contains(normalized)) {
      _ref
          .read(sourceLanguageFilterProvider.notifier)
          .update({...lowerEnabled, normalized}.toList());
    }
    final extEnabled = _ref.read(extensionLanguageFilterProvider);
    final lowerExtEnabled = {
      for (final c in extEnabled ?? const <String>[]) c.toLowerCase(),
    };
    if (!lowerExtEnabled.contains(normalized)) {
      _ref
          .read(extensionLanguageFilterProvider.notifier)
          .update({...lowerExtEnabled, normalized}.toList());
    }
  }

  Future<void> refreshList() async {
    final session = _ref
        .read(authCredentialsStoreProvider.notifier)
        .captureSession();
    if (!_ref.mounted || !session()) return;
    _ref.invalidate(extensionProvider);
    await _ref.read(extensionProvider.future);
    if (!_ref.mounted || !session()) return;
    _ref.invalidate(extensionUpdateBadgeCountProvider);
  }

  Future<void> _refreshAfter(
    Future<void> Function(bool Function()) mutate,
  ) async {
    final session = _ref
        .read(authCredentialsStoreProvider.notifier)
        .captureSession();
    bool current() => _ref.mounted && session();
    if (!current()) return;
    await mutate(current);
    if (!current()) return;
    _ref.invalidate(sourceListProvider);
    return refreshList();
  }
}

// Keep alive across awaited button actions so their refresh can still run.
@Riverpod(keepAlive: true)
ExtensionActions extensionActions(Ref ref) => ExtensionActions(ref);
