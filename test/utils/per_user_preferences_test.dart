import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/features/account/data/account_providers.dart';
import 'package:tsumiru/src/features/auth/data/auth_credentials_store.dart';
import 'package:tsumiru/src/features/library/data/default_category.dart';
import 'package:tsumiru/src/features/settings/presentation/appearance/appearance_screen.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/utils/mixin/shared_preferences_client_mixin.dart';

class _FailingAuthStore extends AuthCredentialsStore {
  @override
  Future<AuthCredentialsState> build() async {
    throw StateError('Keychain failure in build');
  }
}

void main() {
  group('scopedPrefKey', () {
    test('returns bare key name when userId is null', () {
      expect(scopedPrefKey(DBKeys.appTheme, null), 'appTheme');
      expect(scopedPrefKey(DBKeys.pageCurlTransition, null), 'pageCurlTransition');
    });

    test('prefixes user-scoped keys with u_<userId>_ when signed in', () {
      expect(scopedPrefKey(DBKeys.appTheme, 42), 'u_42_appTheme');
      expect(scopedPrefKey(DBKeys.customThemeColor, 7), 'u_7_customThemeColor');
      expect(scopedPrefKey(DBKeys.appLockEnabled, 7), 'u_7_appLockEnabled');
      expect(scopedPrefKey(DBKeys.disableContentSharing, 7), 'u_7_disableContentSharing');
      expect(scopedPrefKey(DBKeys.pageCurlTransition, 7), 'u_7_pageCurlTransition');
      expect(scopedPrefKey(DBKeys.autoScrollSleepTimerMinutes, 7), 'u_7_autoScrollSleepTimerMinutes');
      expect(scopedPrefKey(DBKeys.migrationKeepOriginal, 7), 'u_7_migrationKeepOriginal');
      expect(scopedPrefKey(DBKeys.hideBottomTabLabels, 7), 'u_7_hideBottomTabLabels');
    });

    test('keeps device/connection keys unprefixed even when userId is present', () {
      expect(scopedPrefKey(DBKeys.serverUrl, 42), 'serverUrl');
      expect(scopedPrefKey(DBKeys.serverExternalUrl, 42), 'serverExternalUrl');
      expect(scopedPrefKey(DBKeys.serverPort, 42), 'serverPort');
      expect(scopedPrefKey(DBKeys.serverRequestTimeout, 42), 'serverRequestTimeout');
      expect(scopedPrefKey(DBKeys.autoRefreshOnTimeout, 42), 'autoRefreshOnTimeout');
      expect(scopedPrefKey(DBKeys.autoRefreshRetryDelay, 42), 'autoRefreshRetryDelay');
      expect(scopedPrefKey(DBKeys.authType, 42), 'authType');
      expect(scopedPrefKey(DBKeys.onboardingComplete, 42), 'onboardingComplete');
    });

    test('SharedPreferenceClientMixin notifier can rebuild multiple times without LateInitializationError', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(hideBottomTabLabelsProvider), isFalse);
      container.read(hideBottomTabLabelsProvider.notifier).update(true);
      expect(container.read(hideBottomTabLabelsProvider), isTrue);

      // Force provider rebuild on the same Notifier instance
      container.invalidate(hideBottomTabLabelsProvider);
      expect(container.read(hideBottomTabLabelsProvider), isTrue);
    });

    test('SharedPreferenceClientMixin handles authCredentialsStoreProvider error state gracefully without throwing ProviderException', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authCredentialsStoreProvider.overrideWith(_FailingAuthStore.new),
        ],
      );
      addTearDown(container.dispose);

      // Await the failure to settle in authCredentialsStoreProvider
      try {
        await container.read(authCredentialsStoreProvider.future);
      } catch (_) {}

      expect(() => container.read(hideBottomTabLabelsProvider), returnsNormally);
    });

    test('accountAccessProvider returns user: null without throwing when unauthenticated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final access = await container.read(accountAccessProvider.future);
      expect(access.user, isNull);
    });

    test('defaultCategoryIdProvider handles unauthenticated gracefully without throwing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final defaultId = await container.read(defaultCategoryIdProvider.future);
      expect(defaultId, isNull);
    });
  });
}
