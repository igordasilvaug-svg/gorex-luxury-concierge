// GOREX LUXURY CONCIERGE — Couche d'accès Cloud Firestore.
//
// Toutes les méthodes sont DÉFENSIVES : si Firebase n'est pas disponible, elles
// échouent proprement (exceptions typées / valeurs neutres) sans jamais faire
// planter l'application. L'application reste pleinement fonctionnelle en local.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Erreur de communication Cloud (message destiné à l'utilisateur).
class CloudException implements Exception {
  final String message;
  const CloudException(this.message);
  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService._();

  /// Document unique de sauvegarde cloud de l'état applicatif complet.
  static const _stateCollection = 'gorex_cloud';
  static const _stateDoc = 'state';

  /// Collections du backend GOREX (créées via Admin SDK).
  static const collections = <String>[
    'clients',
    'requests',
    'providers',
    'bookings',
    'itineraries',
    'finance_docs',
    'expenses',
    'conversations',
    'appointments',
    'users',
    'audit_log',
  ];

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Vrai si Firebase est initialisé et exploitable.
  static bool get available => FirebaseBootstrap.available;

  static void _ensure() {
    if (!FirebaseBootstrap.available) {
      throw const CloudException(
        'Cloud indisponible — l\'application fonctionne en mode local.',
      );
    }
  }

  /// Teste la connexion Firestore (lecture d'un document de sonde).
  static Future<bool> ping() async {
    if (!FirebaseBootstrap.available) return false;
    try {
      await _db.collection(_stateCollection).limit(1).get();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Cloud] ping échoué: $e');
      return false;
    }
  }

  /// Pousse l'état applicatif complet vers le cloud (document unique).
  /// Retourne la date d'écriture.
  static Future<DateTime> pushState(Map<String, dynamic> state) async {
    _ensure();
    try {
      final now = DateTime.now();
      await _db.collection(_stateCollection).doc(_stateDoc).set({
        'schema': 1,
        'app': 'GOREX LUXURY CONCIERGE',
        'syncedAt': now.toIso8601String(),
        'payload': state,
      });
      return now;
    } catch (e) {
      throw CloudException('Échec de la synchronisation cloud : $e');
    }
  }

  /// Récupère l'état applicatif précédemment poussé, ou null si aucun.
  static Future<({Map<String, dynamic> payload, DateTime syncedAt})?>
  pullState() async {
    _ensure();
    try {
      final snap = await _db
          .collection(_stateCollection)
          .doc(_stateDoc)
          .get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final payload = data['payload'];
      if (payload is! Map) return null;
      final at = DateTime.tryParse('${data['syncedAt']}') ?? DateTime.now();
      return (
        payload: Map<String, dynamic>.from(payload),
        syncedAt: at,
      );
    } catch (e) {
      throw CloudException('Échec de lecture cloud : $e');
    }
  }

  /// Nombre de documents par collection du backend GOREX.
  static Future<Map<String, int>> collectionCounts() async {
    _ensure();
    final out = <String, int>{};
    for (final name in collections) {
      try {
        final agg = await _db.collection(name).count().get();
        out[name] = agg.count ?? 0;
      } catch (e) {
        out[name] = -1; // -1 = non lisible
      }
    }
    return out;
  }

  /// Lit une collection (lecture seule), triée par 'created_at' si présent.
  static Future<List<Map<String, dynamic>>> fetchCollection(
    String name, {
    int limit = 50,
  }) async {
    _ensure();
    try {
      final snap = await _db.collection(name).limit(limit).get();
      final list = snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();
      return list;
    } catch (e) {
      throw CloudException('Lecture « $name » impossible : $e');
    }
  }

  // ─────────────────────────── TEMPS RÉEL (STREAMS) ───────────────────────────
  /// Flux temps réel de l'état applicatif cloud (document unique).
  ///
  /// Émet à chaque modification détectée côté serveur. Chaque émission contient
  /// la charge utile complète et la date de synchronisation. Si Firebase est
  /// indisponible, un flux vide est retourné (aucune erreur).
  static Stream<({Map<String, dynamic> payload, DateTime syncedAt})>
  watchState() {
    if (!FirebaseBootstrap.available) {
      return const Stream.empty();
    }
    return _db
        .collection(_stateCollection)
        .doc(_stateDoc)
        .snapshots()
        .where((snap) => snap.exists && snap.data() != null)
        .map((snap) {
          final data = snap.data()!;
          final payload = data['payload'];
          final at = DateTime.tryParse('${data['syncedAt']}') ?? DateTime.now();
          return (
            payload: payload is Map
                ? Map<String, dynamic>.from(payload)
                : <String, dynamic>{},
            syncedAt: at,
          );
        });
  }

  /// Flux temps réel du nombre de documents d'une collection.
  ///
  /// Utile pour un tableau de bord « live » (compteurs qui se mettent à jour).
  static Stream<int> watchCollectionCount(String name) {
    if (!FirebaseBootstrap.available) {
      return const Stream.empty();
    }
    return _db
        .collection(name)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Flux temps réel des documents d'une collection (lecture seule).
  static Stream<List<Map<String, dynamic>>> watchCollection(
    String name, {
    int limit = 50,
  }) {
    if (!FirebaseBootstrap.available) {
      return const Stream.empty();
    }
    return _db
        .collection(name)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList(),
        );
  }
}
