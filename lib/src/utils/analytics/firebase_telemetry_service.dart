// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../firebase_options.dart';
import '../../features/notifications/data/local_notification_service.dart';
import '../../routes/router_config.dart';

/// Top-level background message handler required by [FirebaseMessaging].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final notification = message.notification;
    final data = message.data;
    // If the message is data-only on Android/iOS, surface a local notification.
    if (notification == null &&
        (data['title'] != null || data['body'] != null)) {
      final service = LocalNotificationService();
      await service.init();
      await service.showPushNotification(
        id: message.hashCode & 0x7fffffff,
        title: '${data['title'] ?? 'Mangaka FC'}',
        body: '${data['body'] ?? ''}',
        payload: AppTelemetry.encodeFcmDataPayload(data),
      );
    }
  } catch (e) {
    debugPrint('FCM background handler error: $e');
  }
}

/// Central Firebase Analytics & Cloud Messaging (FCM) service for mobile (iOS/Android) and Web.
class AppTelemetry {
  AppTelemetry._();

  static bool _initialized = false;
  static bool _analyticsEnabled = true;
  static FirebaseAnalytics? _analytics;
  static FirebaseMessaging? _messaging;

  /// Reactive notifier holding the current device/web FCM registration token.
  static final ValueNotifier<String?> fcmTokenNotifier =
      ValueNotifier<String?>(null);

  /// Reactive notifier holding whether FCM push notifications are authorized.
  static final ValueNotifier<bool> fcmAuthorizedNotifier =
      ValueNotifier<bool>(false);

  /// Reactive notifier holding whether Firebase Analytics collection is enabled.
  static final ValueNotifier<bool> analyticsEnabledNotifier =
      ValueNotifier<bool>(true);

  static String? get fcmToken => fcmTokenNotifier.value;
  static bool get isInitialized => _initialized;

  /// Pending deep-link route from a cold-start FCM notification tap.
  static String? _pendingFcmRoute;

  static String? consumePendingFcmRoute() {
    final route = _pendingFcmRoute;
    _pendingFcmRoute = null;
    return route;
  }

  /// Callback invoked when a foreground/opened FCM notification requests navigation.
  static void Function(String route)? onNavigateRequested;

  /// Initializes Firebase Core, Analytics, and Cloud Messaging across iOS, Android, and Web.
  static Future<void> init({
    String? appVersion,
    String? buildNumber,
  }) async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(_analyticsEnabled);
      await _analytics?.setDefaultEventParameters({
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'app_version': ?appVersion,
        'build_number': ?buildNumber,
      });
      await _analytics?.logAppOpen();
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase Core/Analytics init skipped or failed: $e');
      return;
    }

    // Initialize Firebase Cloud Messaging (FCM) on iOS, Android, and Web.
    try {
      _messaging = FirebaseMessaging.instance;
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        await _messaging?.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      await requestFcmPermissionAndRegister();

      // Listen for foreground FCM messages.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Listen for background -> foreground notification taps.
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Check if the app was cold-launched by tapping an FCM notification.
      final initialMessage = await _messaging?.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageNavigation(initialMessage, coldStart: true);
      }
    } catch (e) {
      debugPrint('Firebase Messaging init warning: $e');
    }
  }

  /// Requests push notification permissions and fetches/subscribes the FCM token.
  static Future<String?> requestFcmPermissionAndRegister() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      fcmAuthorizedNotifier.value = authorized;

      if (!authorized) return null;

      // On iOS, ensure APNs token is requested before fetching FCM token.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        try {
          await messaging.getAPNSToken();
        } catch (_) {}
      }

      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        fcmTokenNotifier.value = token;
        debugPrint('FCM Token registered: $token');
        logFcmEvent(action: 'token_registered');
      }

      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((newToken) {
        fcmTokenNotifier.value = newToken;
        logFcmEvent(action: 'token_refreshed');
      });

      // Topic subscriptions are supported on native iOS/Android.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)) {
        await subscribeToTopic('all_users');
        await subscribeToTopic('new_chapters');
        await subscribeToTopic('app_updates');
      }
      return token;
    } catch (e) {
      debugPrint('FCM permission/token registration warning: $e');
      return null;
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _messaging?.subscribeToTopic(topic);
      logFcmEvent(action: 'topic_subscribe', topic: topic);
    } catch (e) {
      debugPrint('FCM subscribeToTopic($topic) failed: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      logFcmEvent(action: 'topic_unsubscribe', topic: topic);
    } catch (e) {
      debugPrint('FCM unsubscribeFromTopic($topic) failed: $e');
    }
  }

  static Future<void> setAnalyticsEnabled(bool enabled) async {
    _analyticsEnabled = enabled;
    analyticsEnabledNotifier.value = enabled;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {}
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final title =
        notification?.title ?? data['title']?.toString() ?? 'Mangaka FC';
    final body = notification?.body ?? data['body']?.toString() ?? '';

    logFcmEvent(
      action: 'foreground_received',
      messageId: message.messageId,
      route: resolveRouteFromFcmData(data),
    );

    if (!kIsWeb && (title.isNotEmpty || body.isNotEmpty)) {
      // On Android, FCM does not automatically display notification banners while in foreground;
      // display via LocalNotificationService so the user sees it and can tap it.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final service = LocalNotificationService();
        unawaited(
          service.showPushNotification(
            id: message.hashCode & 0x7fffffff,
            title: title,
            body: body,
            payload: encodeFcmDataPayload(data),
          ),
        );
      }
    }
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleMessageNavigation(message, coldStart: false);
  }

  static void _handleMessageNavigation(
    RemoteMessage message, {
    required bool coldStart,
  }) {
    final route = resolveRouteFromFcmData(message.data);
    logFcmEvent(
      action: coldStart ? 'opened_cold_start' : 'opened_background',
      messageId: message.messageId,
      route: route,
    );
    if (route == null || route.isEmpty) return;
    if (onNavigateRequested != null) {
      onNavigateRequested!(route);
    } else {
      _pendingFcmRoute = route;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        GoRouter.of(ctx).go(route);
        _pendingFcmRoute = null;
      }
    }
  }

  /// Resolves a GoRouter location or `url:...` target from an FCM data map.
  static String? resolveRouteFromFcmData(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    final directRoute = (data['route'] ?? data['path'])?.toString().trim();
    if (directRoute != null && directRoute.isNotEmpty) {
      return directRoute.startsWith('/') ? directRoute : '/$directRoute';
    }
    final externalUrl = data['url']?.toString().trim();
    if (externalUrl != null && externalUrl.isNotEmpty) {
      return 'url:$externalUrl';
    }
    final mangaId = int.tryParse('${data['mangaId'] ?? data['manga_id'] ?? ''}');
    final chapterId = int.tryParse(
      '${data['chapterId'] ?? data['chapter_id'] ?? ''}',
    );
    if (mangaId != null && chapterId != null) {
      return ReaderRoute(mangaId: mangaId, chapterId: chapterId).location;
    }
    if (mangaId != null) {
      return MangaRoute(mangaId: mangaId).location;
    }
    final sourceId = (data['sourceId'] ?? data['source_id'])?.toString().trim();
    if (sourceId != null && sourceId.isNotEmpty) {
      return '/source/$sourceId/POPULAR';
    }
    final action = (data['action'] ?? data['type'] ?? data['screen'])
        ?.toString()
        .trim()
        .toLowerCase();
    return switch (action) {
      'updates' || 'new_chapters' => const UpdatesRoute().location,
      'downloads' => const DownloadsRoute().location,
      'history' => const HistoryTabRoute().location,
      'extensions' => const BrowseExtensionRoute().location,
      'sources' || 'browse' => const BrowseSourceRoute().location,
      'library' => const LibraryRoute(categoryId: 0).location,
      'settings' => const SettingsRoute().location,
      'notifications' => const NotificationsSettingsRoute().location,
      _ => null,
    };
  }

  static String encodeFcmDataPayload(Map<String, dynamic> data) {
    final route = resolveRouteFromFcmData(data);
    if (route != null && route.startsWith('url:')) {
      return route;
    }
    if (route != null) {
      return 'fcm_route:$route';
    }
    return jsonEncode(data);
  }

  // ---------------------------------------------------------------------------
  // Analytics Event Logging Helpers
  // ---------------------------------------------------------------------------

  static void logScreenView({
    required String screenName,
    String? screenClass,
  }) {
    if (!_initialized || !_analyticsEnabled) return;
    unawaited(
      _analytics
          ?.logScreenView(
            screenName: screenName,
            screenClass: screenClass ?? 'FlutterScreen',
          )
          .catchError((_) {}),
    );
  }

  static void setUser({String? username, String? authMode}) {
    if (!_initialized || !_analyticsEnabled) return;
    unawaited(
      _analytics
          ?.setUserId(
            id: (username != null && username.trim().isNotEmpty)
                ? username.trim()
                : null,
          )
          .catchError((_) {}),
    );
    if (authMode != null) {
      setUserProperty(name: 'auth_mode', value: authMode);
    }
  }

  static void setUserProperty({
    required String name,
    required String? value,
  }) {
    if (!_initialized || !_analyticsEnabled) return;
    unawaited(
      _analytics
          ?.setUserProperty(name: name, value: value)
          .catchError((_) {}),
    );
  }

  static void logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) {
    if (!_initialized || !_analyticsEnabled) return;
    final sanitized = <String, Object>{};
    if (parameters != null) {
      for (final entry in parameters.entries) {
        final v = entry.value;
        if (v == null) continue;
        if (v is num || v is String) {
          sanitized[entry.key] = v;
        } else if (v is bool) {
          sanitized[entry.key] = v ? 1 : 0;
        } else {
          sanitized[entry.key] = '$v';
        }
      }
    }
    unawaited(
      _analytics
          ?.logEvent(
            name: name,
            parameters: sanitized.isEmpty ? null : sanitized,
          )
          .catchError((_) {}),
    );
  }

  // Auth & Account Actions
  static void logSignIn({
    required String method,
    String? username,
  }) {
    setUser(username: username, authMode: method);
    if (!_initialized || !_analyticsEnabled) return;
    unawaited(
      _analytics?.logLogin(loginMethod: method).catchError((_) {}),
    );
  }

  static void logSignUp({
    required String method,
    String? username,
  }) {
    setUser(username: username, authMode: method);
    if (!_initialized || !_analyticsEnabled) return;
    unawaited(
      _analytics?.logSignUp(signUpMethod: method).catchError((_) {}),
    );
  }

  static void logSignOut() {
    logEvent('account_sign_out');
    setUser(username: null, authMode: 'none');
  }

  static void logFaceIdAuth({
    required String purpose,
    required bool success,
  }) => logEvent('face_id_auth', {
    'purpose': purpose,
    'success': success ? 1 : 0,
  });

  // Manga & Library Actions
  static void logMangaLibraryChange({
    required int mangaId,
    required bool added,
    int count = 1,
  }) => logEvent(added ? 'manga_add_to_library' : 'manga_remove_from_library', {
    'manga_id': mangaId,
    'count': count,
  });

  static void logMangaCategoryUpdate({
    required int mangaCount,
    required int addedCategories,
    required int removedCategories,
  }) => logEvent('manga_edit_categories', {
    'manga_count': mangaCount,
    'added_categories': addedCategories,
    'removed_categories': removedCategories,
  });

  static void logMangaView({required int mangaId}) =>
      logEvent('manga_view', {'manga_id': mangaId});

  static void logMangaMetaUpdate({
    required int mangaId,
    required String key,
  }) => logEvent('manga_meta_update', {
    'manga_id': mangaId,
    'meta_key': key,
  });

  // Reader, Video & Novel Actions
  static void logChapterOpen({
    required int mangaId,
    required int chapterId,
    String? readerMode,
  }) => logEvent('reader_open_chapter', {
    'manga_id': mangaId,
    'chapter_id': chapterId,
    'reader_mode': ?readerMode,
  });

  static void logChapterCompleted({
    required int mangaId,
    required int chapterId,
    required int totalPages,
  }) => logEvent('reader_complete_chapter', {
    'manga_id': mangaId,
    'chapter_id': chapterId,
    'total_pages': totalPages,
  });

  static void logChapterModify({
    required int count,
    bool? isRead,
    bool? isBookmarked,
  }) => logEvent('chapter_modify', {
    'count': count,
    if (isRead != null) 'is_read': isRead ? 1 : 0,
    if (isBookmarked != null) 'is_bookmarked': isBookmarked ? 1 : 0,
  });

  static void logChapterDelete({required int count}) =>
      logEvent('chapter_delete_downloaded', {'count': count});

  // Downloads Actions
  static void logDownloadAction({
    required String action,
    int? count,
    int? chapterId,
  }) => logEvent('download_$action', {
    'count': ?count,
    'chapter_id': ?chapterId,
  });

  // Browse, Sources & Search Actions
  static void logSourceBrowse({
    required String sourceId,
    required String sourceType,
    required int page,
    String? query,
  }) => logEvent('source_browse', {
    'source_id': sourceId,
    'source_type': sourceType,
    'page': page,
    if (query != null && query.isNotEmpty) 'query': query,
  });

  static void logSourcePinToggle({
    required String sourceId,
    required bool pinned,
  }) => logEvent('source_pin_toggle', {
    'source_id': sourceId,
    'pinned': pinned ? 1 : 0,
  });

  static void logSourceHideToggle({
    required String sourceId,
    required bool hidden,
  }) => logEvent('source_hide_toggle', {
    'source_id': sourceId,
    'hidden': hidden ? 1 : 0,
  });

  static void logSearch({
    required String searchTerm,
    String? scope,
  }) {
    if (!_initialized || !_analyticsEnabled || searchTerm.trim().isEmpty) {
      return;
    }
    unawaited(
      _analytics
          ?.logSearch(
            searchTerm: searchTerm.trim(),
            parameters: scope != null ? {'scope': scope} : null,
          )
          .catchError((_) {}),
    );
  }

  // Extensions & Extension Stores Actions
  static void logExtensionAction({
    required String action,
    required String pkgName,
    String? language,
  }) => logEvent('extension_$action', {
    'pkg_name': pkgName,
    'language': ?language,
  });

  static void logExtensionStoreAction({
    required String action,
    required String indexUrl,
  }) => logEvent('extension_store_$action', {
    'index_url': indexUrl,
  });

  // NSFW / 18+ Privacy & History Actions
  static void logNsfwToggle({
    required bool enabled,
    required String trigger,
  }) {
    setUserProperty(name: 'nsfw_unlocked', value: enabled ? 'true' : 'false');
    logEvent('nsfw_toggle', {
      'enabled': enabled ? 1 : 0,
      'trigger': trigger,
    });
  }

  static void logHistoryQuery({
    String? searchQuery,
    bool? inLibrary,
  }) => logEvent('history_query', {
    if (searchQuery != null && searchQuery.isNotEmpty) 'query': searchQuery,
    if (inLibrary != null) 'in_library': inLibrary ? 1 : 0,
  });

  // FCM Telemetry
  static void logFcmEvent({
    required String action,
    String? messageId,
    String? route,
    String? topic,
  }) => logEvent('fcm_$action', {
    'message_id': ?messageId,
    'route': ?route,
    'topic': ?topic,
  });
}
