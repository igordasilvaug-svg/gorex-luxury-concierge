// GOREX LUXURY CONCIERGE — Configuration Firebase multi-plateforme.
//
// Généré à partir de :
//   • google-services.json        → configuration Android (projet gorex-concierge)
//   • API Firebase Management     → configuration Web  (app "GOREX Concierge Web")
//
// ⚠️ Ce fichier ne contient AUCUN secret serveur : les clés API Web/Android sont
//    des identifiants publics par conception (protégés par les règles Firestore).
//
// L'initialisation est DÉFENSIVE : si Firebase n'est pas disponible (ex. build web
// sans accès réseau, environnement de test), l'application continue de fonctionner
// en mode local (shared_preferences).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      // Les autres plateformes retombent sur la config Web/Android disponible.
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  /// Web — app Firebase "GOREX Concierge Web".
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBXVeAt2W8tmgThLVN6x7TPAG6j89RAYFE',
    appId: '1:724339415341:web:eeabc56bdb2136ae4f1ba4',
    messagingSenderId: '724339415341',
    projectId: 'gorex-concierge',
    authDomain: 'gorex-concierge.firebaseapp.com',
    storageBucket: 'gorex-concierge.firebasestorage.app',
  );

  /// Android — issu de google-services.json (package com.gorexconcierge.luxury).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDoFazGB2cxqOxsObUMQAL9ZU3WEaVIovE',
    appId: '1:724339415341:android:180257674c8df9434f1ba4',
    messagingSenderId: '724339415341',
    projectId: 'gorex-concierge',
    storageBucket: 'gorex-concierge.firebasestorage.app',
  );
}
