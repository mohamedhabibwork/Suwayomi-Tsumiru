// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'redact_tokens.dart';

/// Rustrak (Sentry-compatible) error & issue tracking service for Mangaka FC (Project ID: 21).
class RustrakService {
  RustrakService._();

  static const String dsn =
      'https://a67b804b3e844a1082cac5a717e31978@api-rustrak.firstcallmedical.app/21';
  static const String sentryKey = 'a67b804b3e844a1082cac5a717e31978';
  static const int projectId = 21;
  static const String projectSlug = 'mangaka-fc';
  static const String envelopeEndpoint =
      'https://api-rustrak.firstcallmedical.app/api/21/envelope/';

  static String _release = 'mangaka-fc@1.6.5+5025';
  static String _environment = kReleaseMode ? 'production' : 'development';
  static String? _userId;
  static String? _authMode;
  static final List<Map<String, dynamic>> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 40;

  static bool get _isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static void init({
    required String appVersion,
    required String buildNumber,
    String? environment,
  }) {
    _release = 'mangaka-fc@$appVersion+$buildNumber';
    if (environment != null && environment.isNotEmpty) {
      _environment = environment;
    }
    addBreadcrumb(
      category: 'app.lifecycle',
      message: 'Initialized Rustrak ($_release)',
      level: 'info',
    );
  }

  static void setUser({String? username, String? authMode}) {
    _userId = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : null;
    if (authMode != null) {
      _authMode = authMode;
    }
  }

  static void addBreadcrumb({
    required String category,
    required String message,
    String level = 'info',
    Map<String, dynamic>? data,
  }) {
    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'category': category,
      'message': redactTokens(message),
      'level': level,
      if (data != null && data.isNotEmpty) 'data': data,
    };
    _breadcrumbs.add(entry);
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Captures an exception/error and sends it to Rustrak (`project_id: 21`).
  static Future<String?> captureException(
    Object error, {
    StackTrace? stackTrace,
    String level = 'error',
    String? culprit,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    http.Client? httpClient,
    bool allowInTests = false,
  }) async {
    if (_isFlutterTest && !allowInTests) return null;
    try {
      final eventId = _generateEventId();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final errorType = error.runtimeType.toString();
      final errorValue = redactTokens(error.toString());
      final frames = _parseStackFrames(stackTrace);

      final eventPayload = <String, dynamic>{
        'event_id': eventId,
        'timestamp': nowIso,
        'platform': 'flutter',
        'level': level,
        'logger': 'flutter',
        'release': _release,
        'environment': _environment,
        if (culprit != null && culprit.isNotEmpty) 'culprit': culprit,
        'sdk': {
          'name': 'sentry.dart.flutter',
          'version': '8.0.0',
        },
        'exception': {
          'values': [
            {
              'type': errorType,
              'value': errorValue,
              if (frames.isNotEmpty)
                'stacktrace': {
                  'frames': frames,
                },
            },
          ],
        },
        'tags': {
          'os': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'project': projectSlug,
          'auth_mode': ?_authMode,
          ...?tags,
        },
        if (_userId != null)
          'user': {
            'id': _userId,
            'username': _userId,
          },
        if (_breadcrumbs.isNotEmpty)
          'breadcrumbs': {
            'values': List<Map<String, dynamic>>.from(_breadcrumbs),
          },
        if (extra != null && extra.isNotEmpty) 'extra': extra,
      };

      final envelopeHeader = jsonEncode({
        'event_id': eventId,
        'sent_at': nowIso,
        'dsn': dsn,
      });
      final itemHeader = jsonEncode({
        'type': 'event',
        'content_type': 'application/json',
      });
      final itemBody = jsonEncode(eventPayload);
      final envelope = '$envelopeHeader\n$itemHeader\n$itemBody\n';

      final client = httpClient ?? http.Client();
      try {
        final response = await client
            .post(
              Uri.parse(envelopeEndpoint),
              headers: {
                'Content-Type': 'application/x-sentry-envelope',
                'X-Sentry-Auth':
                    'Sentry sentry_version=7, sentry_key=$sentryKey, sentry_client=rustrak-flutter/1.0',
              },
              body: utf8.encode(envelope),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return eventId;
        }
      } finally {
        if (httpClient == null) {
          client.close();
        }
      }
    } catch (_) {
      // Never throw from the crash reporter.
    }
    return null;
  }

  static String _generateEventId() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static List<Map<String, dynamic>> _parseStackFrames(StackTrace? stack) {
    if (stack == null) return const [];
    final rawLines = redactTokens(stack.toString()).split('\n');
    final frameRegex = RegExp(r'^#\d+\s+([^\(]+)\s+\((.+):(\d+):(\d+)\)$');
    final parsed = <Map<String, dynamic>>[];

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = frameRegex.firstMatch(trimmed);
      if (match != null) {
        final fn = match.group(1)!.trim();
        final file = match.group(2)!.trim();
        final lineno = int.tryParse(match.group(3)!) ?? 0;
        final colno = int.tryParse(match.group(4)!) ?? 0;
        parsed.add({
          'function': fn,
          'filename': file,
          'lineno': lineno,
          'colno': colno,
          'in_app': file.contains('package:tsumiru/') || file.contains('main.dart'),
        });
      }
    }
    // Sentry expects frames ordered from oldest caller to newest frame.
    return parsed.reversed.take(50).toList();
  }
}
