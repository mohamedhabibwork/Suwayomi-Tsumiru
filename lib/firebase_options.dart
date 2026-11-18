// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Mangaka FC (`mangaka-fc-app`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAEW40ijNBdN2aKFRD4cx5p3zVc3AwRXUs',
    appId: '1:255237254114:web:8d9800f1fa6f78bb0827bb',
    messagingSenderId: '255237254114',
    projectId: 'mangaka-fc-app',
    authDomain: 'mangaka-fc-app.firebaseapp.com',
    storageBucket: 'mangaka-fc-app.firebasestorage.app',
    measurementId: 'G-HYMVLS4M4J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAixopm8zHMzxOyBar86x_HycCOVEADxjY',
    appId: '1:255237254114:android:269545cdca246fdb0827bb',
    messagingSenderId: '255237254114',
    projectId: 'mangaka-fc-app',
    storageBucket: 'mangaka-fc-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBF7L5Ev3wKEU-8wYtcai2x0XOSnJOXwHo',
    appId: '1:255237254114:ios:252bed1b537be4950827bb',
    messagingSenderId: '255237254114',
    projectId: 'mangaka-fc-app',
    storageBucket: 'mangaka-fc-app.firebasestorage.app',
    iosBundleId: 'app.firstcallmedical.manga',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBF7L5Ev3wKEU-8wYtcai2x0XOSnJOXwHo',
    appId: '1:255237254114:ios:252bed1b537be4950827bb',
    messagingSenderId: '255237254114',
    projectId: 'mangaka-fc-app',
    storageBucket: 'mangaka-fc-app.firebasestorage.app',
    iosBundleId: 'app.firstcallmedical.manga',
  );
}
