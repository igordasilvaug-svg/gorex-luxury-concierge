import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/client.dart';
import '../../models/company_profile.dart';
import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../models/peppol_config.dart';
import 'peppol_ubl_generator.dart';

/// Résultat d'une opération d'envoi via un Access Point Peppol.
class PeppolSendResult {
  final bool success;
  final int? statusCode;
  final String message;
  final String? providerReference; // id renvoyé par l'Access Point
  final bool simulated;

  const PeppolSendResult({
    required this.success,
    required this.message,
    this.statusCode,
    this.providerReference,
    this.simulated = false,
  });
}

/// Client HTTP vers un **Access Point Peppol agréé** (API REST type Storecove).
///
/// En production, l'Access Point est responsable de l'interopérabilité
/// (résolution SMP, validation BIS Billing 3.0, remise au destinataire).
/// Cette classe se contente de transmettre le document UBL signé du contexte.
class PeppolService {
  PeppolService._();

  /// Construit le corps JSON compatible Storecove à partir du UBL.
  static Map<String, dynamic> buildStorecovePayload({
    required PeppolConfig config,
    required String ublXml,
    required String filename,
    required bool isInvoice,
  }) {
    return {
      'legal_entity_id': int.tryParse(config.senderLegalEntityId) ?? 1,
      'document': {
        'document_type': isInvoice ? 'invoice' : 'invoice',
        'raw_document': {
          'raw_document_data': base64Encode(utf8.encode(ublXml)),
          'raw_document_type': 'xml',
        },
        'meta': {'filename': filename},
      },
    };
  }

  /// Transmet une facture via l'Access Point configuré.
  ///
  /// Si [config] n'est pas configurée, l'envoi est **simulé** (mode
  /// démonstration) et renvoie un succès marqué `simulated: true`.
  static Future<PeppolSendResult> send({
    required FinanceDocument document,
    required Client? client,
    required CompanyProfile company,
    required PeppolConfig config,
  }) async {
    final ubl = PeppolUblGenerator.generate(
      f: document,
      client: client,
      company: company,
    );

    if (!config.isConfigured) {
      return PeppolSendResult(
        success: true,
        simulated: true,
        message:
            'Envoi simulé (Access Point non configuré). Document UBL prêt '
            '(${ubl.filename}, ${ubl.xml.length} octets).',
      );
    }

    final uri = Uri.parse(
      '${config.apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/document_submissions',
    );
    final payload = buildStorecovePayload(
      config: config,
      ublXml: ubl.xml,
      filename: ubl.filename,
      isInvoice: document.type == FinanceDocType.invoice,
    );

    try {
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: config.timeoutSeconds));

      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      String? ref;
      if (resp.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map) {
            ref =
                (decoded['guid'] ??
                        decoded['id'] ??
                        decoded['document_submission_guid'] ??
                        decoded['tracking_id'])
                    ?.toString();
          }
        } catch (_) {
          // corps non JSON — ignoré
        }
      }

      return PeppolSendResult(
        success: ok,
        statusCode: resp.statusCode,
        providerReference: ref,
        message: ok
            ? 'Document transmis à l\'Access Point Peppol.'
            : 'Échec de transmission (HTTP ${resp.statusCode}) : '
                  '${resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body}',
      );
    } on TimeoutException {
      return PeppolSendResult(
        success: false,
        message:
            'Délai dépassé (${config.timeoutSeconds}s) — vérifiez la connectivité '
            'de l\'Access Point.',
      );
    } catch (e) {
      return PeppolSendResult(
        success: false,
        message: 'Erreur réseau : $e',
      );
    }
  }

  /// Interroge l'Access Point pour obtenir le statut d'une soumission.
  ///
  /// Retourne le statut Peppol mappé depuis la réponse du fournisseur,
  /// ou `null` si le statut ne peut pas être déterminé.
  static Future<PeppolStatus?> getSubmissionStatus({
    required PeppolConfig config,
    required String providerReference,
  }) async {
    if (!config.isConfigured || providerReference.isEmpty) return null;
    final uri = Uri.parse(
      '${config.apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}'
      '/document_submissions/$providerReference',
    );
    try {
      final resp = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
          )
          .timeout(Duration(seconds: config.timeoutSeconds));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      return parseStatusFromBody(resp.body);
    } catch (_) {
      return null;
    }
  }

  /// Mappe un corps JSON (Storecove / générique) vers un [PeppolStatus].
  static PeppolStatus? parseStatusFromBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      // Storecove : document_submission_status + events[]
      final raw =
          (decoded['document_submission_status'] ??
                  decoded['status'] ??
                  decoded['state'] ??
                  decoded['delivery_status'])
              ?.toString()
              .toUpperCase();
      final events = decoded['events'];
      String? lastEvent;
      if (events is List && events.isNotEmpty) {
        final last = events.last;
        if (last is Map) {
          lastEvent = (last['event_type'] ?? last['type'] ?? last['status'])
              ?.toString()
              .toUpperCase();
        }
      }
      return _mapStatus(raw, lastEvent);
    } catch (_) {
      return null;
    }
  }

  static PeppolStatus _mapStatus(String? raw, String? lastEvent) {
    final s = '${raw ?? ''} ${lastEvent ?? ''}'.toUpperCase();
    if (s.contains('DELIVER') ||
        s.contains('ACCEPT') ||
        s.contains('RECEIVED') ||
        s.contains('COMPLETED')) {
      return PeppolStatus.delivered;
    }
    if (s.contains('FAIL') ||
        s.contains('ERROR') ||
        s.contains('REJECT') ||
        s.contains('UNDELIVER')) {
      return PeppolStatus.failed;
    }
    if (s.contains('SENT') ||
        s.contains('SUBMIT') ||
        s.contains('SEND') ||
        s.contains('IN_PROGRESS') ||
        s.contains('PROCESSING') ||
        s.contains('PENDING')) {
      return PeppolStatus.sent;
    }
    return PeppolStatus.sent;
  }

  /// Teste la connexion à l'Access Point (liste des entités légales).
  static Future<PeppolSendResult> testConnection(PeppolConfig config) async {
    if (!config.isConfigured) {
      return const PeppolSendResult(
        success: false,
        message: 'Configuration incomplète (URL, clé API ou identifiant manquant).',
      );
    }
    final uri = Uri.parse(
      '${config.apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/legal_entities',
    );
    try {
      final resp = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
          )
          .timeout(Duration(seconds: config.timeoutSeconds));
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      return PeppolSendResult(
        success: ok,
        statusCode: resp.statusCode,
        message: ok
            ? 'Connexion à l\'Access Point réussie.'
            : 'Connexion refusée (HTTP ${resp.statusCode}).',
      );
    } on TimeoutException {
      return const PeppolSendResult(
        success: false,
        message: 'Délai dépassé lors du test de connexion.',
      );
    } catch (e) {
      return PeppolSendResult(
        success: false,
        message: 'Erreur réseau : $e',
      );
    }
  }
}
