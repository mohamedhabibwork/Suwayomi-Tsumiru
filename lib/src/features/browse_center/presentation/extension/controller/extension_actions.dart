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
import '../../../../../utils/misc/toast/toast.dart';
import '../../../../auth/data/auth_credentials_store.dart';
import '../../../data/extension_repository/extension_repository.dart';
import '../../../data/extension_store_repository/extension_store_repository.dart';
import '../../../data/source_repository/source_repository.dart';
import '../../../domain/extension/top_extensions.dart';
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
    return _refreshAfter((current) async {
      final beforePkgs = {
        for (final e in _ref.read(extensionProvider).value ?? const [])
          if (e.isInstalled.ifNull()) e.pkgName.trim().toLowerCase(),
      };
      await _repository.installExtensionFile(context, file: file);
      if (!current()) return;
      final defaultDisabled =
          _ref.read(newExtensionsDisabledByDefaultProvider) ?? true;
      if (defaultDisabled) {
        _ref.invalidate(extensionProvider);
        final afterList = await _ref.read(extensionProvider.future);
        if (!current()) return;
        for (final ext in afterList ?? const []) {
          final norm = ext.pkgName.trim().toLowerCase();
          if (ext.isInstalled.ifNull() && !beforePkgs.contains(norm)) {
            await setExtensionEnabled(ext.pkgName, false);
          }
        }
      }
    });
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
    _ref.read(disabledExtensionsProvider.notifier).setEnabled(pkgName, true);
    return _refreshAfter((_) => _repository.uninstallExtension(pkgName));
  }

  /// Enables or disables an installed extension and syncs the hidden state of
  /// all its sources so disabled extensions do not appear in Browse Sources.
  Future<void> setExtensionEnabled(String pkgName, bool enabled) async {
    AppTelemetry.logExtensionAction(
      action: enabled ? 'enable' : 'disable',
      pkgName: pkgName,
    );
    _ref.read(disabledExtensionsProvider.notifier).setEnabled(pkgName, enabled);
    try {
      final normalizedPkg = pkgName.trim().toLowerCase();
      var sources = _ref.read(sourceListProvider).value;
      if (sources == null || sources.isEmpty) {
        sources = await _ref.read(sourceListProvider.future);
      }
      final matching = (sources ?? const [])
          .where((s) => s.$extension.pkgName.trim().toLowerCase() == normalizedPkg)
          .toList();
      if (matching.isNotEmpty) {
        final sourceRepo = _ref.read(sourceRepositoryProvider);
        await Future.wait(
          matching.map((s) => sourceRepo.setSourceHidden(s.id, !enabled)),
        );
        _ref.invalidate(sourceListProvider);
      }
    } catch (_) {}
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
    final defaultDisabled =
        _ref.read(newExtensionsDisabledByDefaultProvider) ?? true;
    if (defaultDisabled) {
      _ref.invalidate(sourceListProvider);
      await setExtensionEnabled(pkgName, false);
      _ref
          .read(toastProvider)
          ?.show(
            'Installed (Disabled by default — toggle switch to enable)',
            withMicrotask: true,
          );
    } else {
      _ref.read(disabledExtensionsProvider.notifier).setEnabled(pkgName, true);
    }
    if (resolvedLang.isNotBlank) _enableSourceLanguage(resolvedLang!);
  }

  /// Automatically syncs the Miyomi extension stores, checks for extension updates,
  /// installs any available updates, removes any installed video extensions, and
  /// refreshes the source catalog when [autoUpdateExtensionsProvider] is true.
  Future<void> autoUpdateInstalledExtensions() async {
    final autoUpdate = _ref.read(autoUpdateExtensionsProvider) ?? true;
    final session = _ref
        .read(authCredentialsStoreProvider.notifier)
        .captureSession();
    if (!_ref.mounted || !session()) return;
    try {
      // Automatically ensure all Miyomi default Manga, Novel, Aidoku & Mangayomi stores exist.
      try {
        final storeList = await _ref.read(extensionStoreListProvider.future);
        if (_ref.mounted && session()) {
          final existingUrls = {
            ...?storeList?.stores.map((s) => s.indexUrl),
          };
          var addedAnyStore = false;
          for (final preset in kCuratedExtensionStores.where(
            (s) => s.isDefault && !s.isNsfw,
          )) {
            if (isExtensionStoreUrlPresent(preset.indexUrl, existingUrls)) {
              continue;
            }
            try {
              await _ref
                  .read(extensionStoreRepositoryProvider)
                  .addStore(preset.indexUrl);
              existingUrls.add(preset.indexUrl);
              addedAnyStore = true;
            } catch (_) {}
          }
          if (addedAnyStore && _ref.mounted && session()) {
            _ref.invalidate(extensionStoreListProvider);
          }
        }
      } catch (_) {}

      _ref.invalidate(extensionProvider);
      final extensions = await _ref.read(extensionProvider.future);
      if (!_ref.mounted || !session() || extensions == null) return;
      final videoInstalled = [
        for (final e in extensions)
          if (e.isInstalled.ifNull() &&
              (e.pkgName.toLowerCase().contains('.animeextension.') ||
                  e.name.toLowerCase().contains('(video)')))
            e.pkgName,
      ];
      for (final pkg in videoInstalled) {
        try {
          await uninstall(pkg);
        } catch (_) {}
      }
      if (!autoUpdate) return;
      final toUpdate = [
        for (final e in extensions)
          if (e.isInstalled.ifNull() &&
              e.hasUpdate.ifNull() &&
              !videoInstalled.contains(e.pkgName))
            e.pkgName,
      ];
      if (toUpdate.isNotEmpty) {
        await updateAll(toUpdate);
      } else {
        _ref.invalidate(sourceListProvider);
      }
    } catch (_) {}
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
