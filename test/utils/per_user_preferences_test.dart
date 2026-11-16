import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/constants/db_keys.dart';
import 'package:tsumiru/src/utils/mixin/shared_preferences_client_mixin.dart';

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
      expect(scopedPrefKey(DBKeys.authType, 42), 'authType');
      expect(scopedPrefKey(DBKeys.onboardingComplete, 42), 'onboardingComplete');
    });
  });
}
