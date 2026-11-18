// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../constants/db_keys.dart';
import '../../../constants/enum.dart';
import '../../../utils/analytics/firebase_telemetry_service.dart';
import '../../account/data/account_actions.dart';
import '../../settings/presentation/server/widget/client/server_url_tile/server_url_tile.dart';
import '../data/secure_credentials_provider.dart';
import 'sign_in_action.dart';

const _biometricsChannel = MethodChannel(
  'app.firstcallmedical.manga/biometrics',
);

String _faceIdStorageKey(String serverBaseUrl) {
  final trimmed = serverBaseUrl.trim().toLowerCase().replaceAll(
    RegExp(r'/+$'),
    '',
  );
  return 'auth.faceid.credentials.${trimmed.isEmpty ? 'default' : trimmed}';
}

const _defaultFaceIdStorageKey = 'auth.faceid.credentials.default';

/// Prompts Face ID / Touch ID on iOS; falls back to true when unavailable (e.g. desktop/tests).
Future<bool> authenticateWithFaceId({
  String reason = 'Authenticate with Face ID to sign in to Mangaka FC',
}) async {
  try {
    final ok = await _biometricsChannel.invokeMethod<bool>('authenticate', {
      'reason': reason,
    });
    final success = ok ?? true;
    AppTelemetry.logFaceIdAuth(purpose: reason, success: success);
    return success;
  } on MissingPluginException {
    return true;
  } on PlatformException {
    AppTelemetry.logFaceIdAuth(purpose: reason, success: false);
    return false;
  } catch (_) {
    return true;
  }
}

Future<void> saveFaceIdCredentials(
  FlutterSecureStorage storage, {
  required String serverBaseUrl,
  required String username,
  required String password,
}) async {
  if (username.trim().isEmpty || password.isEmpty) return;
  final payload = jsonEncode({
    'username': username.trim(),
    'password': password,
  });
  await writeSecure(storage, _faceIdStorageKey(serverBaseUrl), payload);
  await writeSecure(storage, _defaultFaceIdStorageKey, payload);
}

Future<({String username, String password})?> readFaceIdCredentials(
  FlutterSecureStorage storage, {
  required String serverBaseUrl,
}) async {
  final raw =
      await readSecureOrAbsent(storage, _faceIdStorageKey(serverBaseUrl)) ??
      await readSecureOrAbsent(storage, _defaultFaceIdStorageKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final user = (map['username'] as String?)?.trim();
    final pass = map['password'] as String?;
    if (user == null || user.isEmpty || pass == null || pass.isEmpty) {
      return null;
    }
    return (username: user, password: pass);
  } catch (_) {
    return null;
  }
}

({String username, String password}) generateFaceIdAccount() {
  final rng = Random.secure();
  const hexChars = '0123456789abcdef';
  const passChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^&*';
  final userSuffix = List.generate(
    8,
    (_) => hexChars[rng.nextInt(hexChars.length)],
  ).join();
  final password = List.generate(
    24,
    (_) => passChars[rng.nextInt(passChars.length)],
  ).join();
  return (username: 'user_$userSuffix', password: password);
}

/// Authenticates with Face ID, then signs in with provided or stored credentials, or auto-generates and registers a new account.
Future<String> signInOrRegisterWithFaceId(
  WidgetRef ref, {
  String? serverBaseUrl,
  String? username,
  String? password,
  AuthType authType = AuthType.uiLogin,
}) async {
  final authenticated = await authenticateWithFaceId();
  if (!authenticated) {
    throw StateError('Face ID authentication was cancelled');
  }
  final storage = ref.read(secureStorageProvider);
  final base = (serverBaseUrl != null && serverBaseUrl.trim().isNotEmpty)
      ? serverBaseUrl.trim()
      : (ref.read(serverUrlProvider) ?? DBKeys.serverUrl.initial);

  // If the user entered a username and password on the landing/login form, sign in with those and save them for Face ID.
  if (username != null &&
      username.trim().isNotEmpty &&
      password != null &&
      password.isNotEmpty) {
    final trimmedUser = username.trim();
    await performSignIn(
      ref,
      authType: authType,
      serverBaseUrl: base,
      username: trimmedUser,
      password: password,
      saveToFaceId: true,
    );
    return trimmedUser;
  }

  final saved = await readFaceIdCredentials(storage, serverBaseUrl: base);
  if (saved != null) {
    try {
      await performSignIn(
        ref,
        authType: AuthType.uiLogin,
        serverBaseUrl: base,
        username: saved.username,
        password: saved.password,
      );
      return saved.username;
    } catch (_) {
      await ref
          .read(accountActionsProvider)
          .redeemCode(
            code: '',
            username: saved.username,
            password: saved.password,
          );
      return saved.username;
    }
  }

  final generated = generateFaceIdAccount();
  await ref
      .read(accountActionsProvider)
      .redeemCode(
        code: '',
        username: generated.username,
        password: generated.password,
      );
  await saveFaceIdCredentials(
    storage,
    serverBaseUrl: base,
    username: generated.username,
    password: generated.password,
  );
  return generated.username;
}
