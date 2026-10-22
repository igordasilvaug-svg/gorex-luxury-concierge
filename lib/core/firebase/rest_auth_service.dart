// GOREX GROUP — Authentification Firebase par API REST officielle.
//
// VOIE PRINCIPALE de connexion sur le Web.
//
// Pourquoi ne pas dépendre du SDK Firebase JavaScript :
// Le SDK Web dépend de scripts chargés depuis gstatic.com et de mécanismes
// (IndexedDB, iframes, TrustedTypes) que certains navigateurs — notamment
// Safari sur macOS — bloquent ou limitent. Résultat constaté en production :
// « Service de connexion indisponible » et impossibilité totale de se connecter.
//
// Ce service appelle donc DIRECTEMENT les API officielles Google/Firebase en
// HTTPS, sans aucun SDK ni script tiers :
//   • Identity Toolkit : connexion e-mail / mot de passe, mise à jour du mot
//                        de passe, envoi du lien de réinitialisation ;
//   • Firestore REST   : lecture des fiches métier `staff/{uid}` et `clients`.
//
// Aucun secret n'est manipulé : la clé API Web est publique par conception
// (elle figure déjà dans le code compilé de l'application).

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Résultat d'une connexion REST.
class RestSignInResult {
  const RestSignInResult({
    required this.ok,
    this.uid,
    this.idToken,
    this.email,
    this.error,
  });

  final bool ok;
  final String? uid;
  final String? idToken;
  final String? email;

  /// Code d'erreur normalisé (même vocabulaire que FirebaseAuthService) :
  /// WRONG_PASSWORD, EMAIL_NOT_FOUND, INVALID_EMAIL, USER_DISABLED,
  /// TOO_MANY_REQUESTS, NETWORK, INVALID_LOGIN_CREDENTIALS…
  final String? error;
}

/// Résultat d'une lecture Firestore REST.
///
/// `status == 0` signale une impossibilité réseau (aucune conclusion possible),
/// à distinguer d'un document réellement absent (404) ou d'un refus de règle
/// de sécurité (403).
class RestFetch {
  const RestFetch(this.data, this.status);

  final Map<String, dynamic>? data;
  final int status;

  bool get networkError => status == 0;
  bool get found => data != null;

  /// Lecture aboutie : soit le document existe, soit il est absent.
  /// Une lecture refusée (403/401) rend le résultat non concluant.
  bool get conclusive => status == 200 || status == 404;
}

class RestAuthService {
  RestAuthService._();

  /// Clé API Web (publique) et identifiant du projet — cf. firebase_options.dart.
  static const String _apiKey = 'AIzaSyBXVeAt2W8tmgThLVN6x7TPAG6j89RAYFE';
  static const String _projectId = 'gorex-concierge';
  static const String _identityBase = 'https://identitytoolkit.googleapis.com/v1';
  static const String _firestoreBase =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  /// Délai maximal d'un appel (réseau mobile lent toléré).
  static const Duration _timeout = Duration(seconds: 25);

  /// En-tête sans pré-vol CORS : `text/plain` est une « simple request »,
  /// le navigateur n'émet donc PAS de requête OPTIONS préalable. Cela supprime
  /// une source classique d'échec silencieux sur Safari (ITP / extensions).
  static const Map<String, String> _plainHeaders = {
    'Content-Type': 'text/plain;charset=utf-8',
  };

  static Map<String, String> _jsonHeaders(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  // ─────────────────────── CONNEXION ───────────────────────

  /// Connexion e-mail / mot de passe via Identity Toolkit.
  static Future<RestSignInResult> signIn(String email, String password) async {
    final payload = jsonEncode({
      'email': email.trim().toLowerCase(),
      'password': password,
      'returnSecureToken': true,
    });

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$_identityBase/accounts:signInWithPassword?key=$_apiKey'),
            headers: _plainHeaders,
            body: payload,
          )
          .timeout(_timeout);
    } catch (_) {
      return const RestSignInResult(ok: false, error: 'NETWORK');
    }

    Map<String, dynamic> body = const {};
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}

    if (resp.statusCode == 200) {
      return RestSignInResult(
        ok: true,
        uid: body['localId'] as String?,
        idToken: body['idToken'] as String?,
        email: body['email'] as String?,
      );
    }

    final err = (body['error'] as Map?)?['message'] as String?;
    if (err == null && resp.statusCode >= 500) {
      return const RestSignInResult(ok: false, error: 'NETWORK');
    }
    return RestSignInResult(ok: false, error: _normalize(err));
  }

  /// Normalise les messages d'erreur Google vers notre vocabulaire commun.
  static String _normalize(String? raw) {
    final m = (raw ?? '').toUpperCase();
    if (m.contains('INVALID_PASSWORD')) return 'WRONG_PASSWORD';
    if (m.contains('EMAIL_NOT_FOUND')) return 'EMAIL_NOT_FOUND';
    if (m.contains('INVALID_EMAIL')) return 'INVALID_EMAIL';
    if (m.contains('INVALID_LOGIN_CREDENTIALS')) return 'INVALID_LOGIN_CREDENTIALS';
    if (m.contains('INVALID_IDP_RESPONSE')) return 'INVALID_LOGIN_CREDENTIALS';
    if (m.contains('USER_DISABLED')) return 'USER_DISABLED';
    if (m.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) return 'TOO_MANY_REQUESTS';
    if (m.contains('QUOTA')) return 'TOO_MANY_REQUESTS';
    if (m.contains('INVALID_API_KEY')) return 'OPERATION_NOT_ALLOWED';
    if (m.contains('PASSWORD_LOGIN_DISABLED')) return 'OPERATION_NOT_ALLOWED';
    if (m.contains('OPERATION_NOT_ALLOWED')) return 'OPERATION_NOT_ALLOWED';
    return m.isEmpty ? 'UNKNOWN' : m;
  }

  // ─────────────────────── PROFILS ───────────────────────

  /// Lit la fiche métier `staff/{uid}`.
  static Future<RestFetch> fetchStaffProfile(String uid, String idToken) async {
    http.Response resp;
    try {
      resp = await http
          .get(
            Uri.parse('$_firestoreBase/staff/$uid'),
            headers: _jsonHeaders(idToken),
          )
          .timeout(_timeout);
    } catch (_) {
      return const RestFetch(null, 0);
    }
    if (resp.statusCode != 200) return RestFetch(null, resp.statusCode);
    return RestFetch(_flatDocument(resp.body, id: uid), 200);
  }

  /// Recherche une fiche `staff` par e-mail.
  static Future<RestFetch> findStaffByEmail(
    String email,
    String idToken,
  ) => _queryByEmail('staff', email, idToken);

  /// Recherche une fiche `clients` par e-mail (comptes clients VIP).
  static Future<RestFetch> findClientByEmail(
    String email,
    String idToken,
  ) => _queryByEmail('clients', email, idToken);

  /// Requête Firestore REST `where field == value` (limit 1).
  static Future<RestFetch> _queryByEmail(
    String collection,
    String email,
    String idToken,
  ) async {
    final query = jsonEncode({
      'structuredQuery': {
        'from': [
          {'collectionId': collection},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'email'},
            'op': 'EQUAL',
            'value': {'stringValue': email.trim().toLowerCase()},
          },
        },
        'limit': 1,
      },
    });

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$_firestoreBase:runQuery'),
            headers: _jsonHeaders(idToken),
            body: query,
          )
          .timeout(_timeout);
    } catch (_) {
      return const RestFetch(null, 0);
    }
    if (resp.statusCode != 200) return RestFetch(null, resp.statusCode);

    // `:runQuery` retourne [] quand aucun document ne correspond.
    try {
      final list = jsonDecode(resp.body) as List;
      for (final item in list) {
        final doc = (item as Map)['document'];
        if (doc is Map && doc['fields'] is Map) {
          final id = (doc['name'] as String?)?.split('/').last;
          return RestFetch(_flatDocument(resp.body, raw: doc, id: id), 200);
        }
      }
      return const RestFetch(null, 200);
    } catch (_) {
      return const RestFetch(null, 0);
    }
  }

  /// Convertit un document Firestore REST en carte simple.
  static Map<String, dynamic>? _flatDocument(
    String rawBody, {
    Map? raw,
    String? id,
  }) {
    Object? docOrBody;
    if (raw != null) {
      docOrBody = raw;
    } else {
      try {
        docOrBody = jsonDecode(rawBody);
      } catch (_) {
        return null;
      }
    }
    if (docOrBody is! Map) return null;
    final fields = docOrBody['fields'];
    if (fields is! Map) return null;

    final flat = <String, dynamic>{};
    fields.forEach((key, value) {
      flat['$key'] = _decodeValue(value);
    });
    final docId = id ?? (docOrBody['name'] as String?)?.split('/').last;
    if (docId != null) {
      flat['id'] = docId;
      flat['uid'] ??= docId;
    }
    return flat;
  }

  /// Décode une valeur Firestore REST (`{stringValue: …}`) en Dart simple.
  static dynamic _decodeValue(dynamic v) {
    if (v is! Map) return null;
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('integerValue')) {
      return int.tryParse('${v['integerValue']}');
    }
    if (v.containsKey('doubleValue')) {
      final d = v['doubleValue'];
      return d is num ? d.toDouble() : double.tryParse('$d');
    }
    if (v.containsKey('timestampValue')) return '${v['timestampValue']}';
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('arrayValue')) {
      final arr = v['arrayValue'];
      final vals = (arr is Map ? arr['values'] : null) as List?;
      return vals?.map(_decodeValue).toList() ?? <dynamic>[];
    }
    if (v.containsKey('mapValue')) {
      final m = v['mapValue'];
      final f = (m is Map ? m['fields'] : null) as Map?;
      if (f == null) return <String, dynamic>{};
      return f.map((k, val) => MapEntry('$k', _decodeValue(val)));
    }
    return null;
  }

  // ─────────────────────── MOT DE PASSE ───────────────────────

  /// Change le mot de passe de l'utilisateur connecté (via idToken).
  static Future<bool> updatePassword(String idToken, String newPassword) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_identityBase/accounts:update?key=$_apiKey'),
            headers: _plainHeaders,
            body: jsonEncode({
              'idToken': idToken,
              'password': newPassword,
              'returnSecureToken': true,
            }),
          )
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envoie un e-mail de réinitialisation de mot de passe.
  static Future<bool> sendPasswordReset(String email) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_identityBase/accounts:sendOobCode?key=$_apiKey'),
            headers: _plainHeaders,
            body: jsonEncode({
              'requestType': 'PASSWORD_RESET',
              'email': email.trim().toLowerCase(),
            }),
          )
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Marque `mustChangePassword = false` dans la fiche `staff/{uid}`.
  static Future<bool> clearMustChangePassword(
    String uid,
    String idToken,
  ) async {
    try {
      final resp = await http
          .patch(
            Uri.parse(
              '$_firestoreBase/staff/$uid'
              '?updateMask.fieldPaths=mustChangePassword',
            ),
            headers: _jsonHeaders(idToken),
            body: jsonEncode({
              'fields': {
                'mustChangePassword': {'booleanValue': false},
              },
            }),
          )
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────── PISTE D'AUDIT ───────────────────────

  /// Ajoute une entrée dans `audit_log` (append-only) via Firestore REST.
  ///
  /// Indispensable au respect de l'exigence « journal d'audit » : sans cela,
  /// les événements de connexion ne sont pas persistés sur les navigateurs où
  /// le SDK Firebase est indisponible (Safari notamment).
  static Future<bool> appendAuditLog(
    String idToken,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_firestoreBase/audit_log'),
            headers: _jsonHeaders(idToken),
            body: jsonEncode({'fields': _encodeFields(data)}),
          )
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Encode une carte Dart en « fields » Firestore REST (types explicites).
  static Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      final enc = _encodeValue(v);
      if (enc != null) out[k] = enc;
    });
    return out;
  }

  static Map<String, dynamic>? _encodeValue(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v is String) {
      // Un horodatage ISO 8601 est mappé sur le type natif `timestampValue`.
      // Firestore REST EXIGE un fuseau : si la chaîne n'en porte pas, on
      // suppose l'UTC et on l'explicite (sinon erreur 400).
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(v)) {
        final hasZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(v);
        return {'timestampValue': hasZone ? v : '${v}Z'};
      }
      return {'stringValue': v};
    }
    if (v is List) {
      return {
        'arrayValue': {
          'values': v.map(_encodeValue).whereType<Map<String, dynamic>>().toList(),
        },
      };
    }
    if (v is Map) {
      return {
        'mapValue': {'fields': _encodeFields(Map<String, dynamic>.from(v))},
      };
    }
    return {'stringValue': '$v'};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LECTURE DE COLLECTIONS PAR REST (sans SDK)
  //
  // Indispensable en production : le SDK Firebase est précisément défaillant
  // sur Safari, donc `FirestoreService` (bâti sur le SDK) ne peut pas
  // alimenter les écrans. Ces méthodes rendent la liste réellement présente
  // en base, indépendamment du SDK.
  // ═══════════════════════════════════════════════════════════════════════

  /// Lit au maximum [limit] documents d'une collection.
  ///
  /// Retourne une liste vide en cas d'échec : l'appelant ne doit jamais
  /// afficher de données inventées pour masquer une panne.
  static Future<List<Map<String, dynamic>>> fetchCollection(
    String collection,
    String idToken, {
    int limit = 100,
  }) async {
    http.Response resp;
    try {
      resp = await http
          .get(
            Uri.parse('$_firestoreBase/$collection?pageSize=$limit'),
            headers: _jsonHeaders(idToken),
          )
          .timeout(_timeout);
    } catch (_) {
      return const [];
    }
    if (resp.statusCode != 200) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];
    final docs = decoded['documents'];
    if (docs is! List) return const [];

    final out = <Map<String, dynamic>>[];
    for (final d in docs) {
      if (d is! Map) continue;
      final name = d['name'];
      final docId = name is String && name.contains('/')
          ? name.split('/').last
          : '';
      final flat = _flatDocument('', raw: d, id: docId);
      if (flat != null) out.add(flat);
    }
    return out;
  }
}
