// GOREX LUXURY CONCIERGE — Génération d'un ordre de prélèvement SEPA.
//
// Produit un fichier ISO 20022 `pain.008.001.02` (Customer Direct Debit
// Initiation) déposable auprès de la banque pour prélever les abonnements.
//
// ── RÈGLE STRUCTURANTE ──────────────────────────────────────────────────
// Un bloc `PmtInf` ne porte QU'UNE date d'exécution (`ReqdColltnDt`) et
// QU'UNE séquence (`SeqTp`). Des ordres de dates ou de séquences différentes
// ne peuvent donc pas cohabiter dans un même bloc : le générateur les regroupe
// automatiquement. Les mettre ensemble produit un fichier rejeté.
//
// Ce fichier n'envoie rien : il produit le XML. La transmission à la banque
// se fait par votre canal habituel (e-banking, Isabel, access point).

import '../../models/company_profile.dart';
import '../../models/sepa_mandate.dart';
import 'sepa_validator.dart';

/// Résultat de la génération, avec le détail des ordres écartés.
class SepaBatchResult {
  final String xml;
  final String filename;

  /// Nombre d'ordres inclus dans le fichier.
  final int included;

  /// Ordres refusés, avec la raison (jamais ignorés en silence).
  final List<String> excluded;

  /// Somme des montants inclus.
  final double total;

  const SepaBatchResult({
    required this.xml,
    required this.filename,
    required this.included,
    required this.excluded,
    required this.total,
  });

  bool get isEmpty => included == 0;
}

class SepaPain008Generator {
  SepaPain008Generator._();

  /// Échappement XML — indispensable : un nom de client contenant « & » ou
  /// « < » produirait un fichier invalide, rejeté sans explication par la banque.
  static String _esc(String? v) {
    if (v == null) return '';
    return v
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Tronque à 35 caractères (limite SEPA de nombreux champs de référence).
  static String _ref35(String v) =>
      v.length <= 35 ? v : v.substring(0, 35);

  static String _amount(double v) => v.toStringAsFixed(2);

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _dateTime(DateTime d) {
    final l = d.toLocal();
    return '${_date(l)}T'
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}:'
        '${l.second.toString().padLeft(2, '0')}';
  }

  /// Construit le fichier de prélèvement.
  ///
  /// [debits]    : ordres à prélever.
  /// [mandates]  : mandats indexés par identifiant (source de la référence et
  ///               de la date de signature — données contractuelles).
  /// [company]   : créancier (nom, IBAN de recouvrement, ICS).
  /// [creditorId]: identifiant créancier SEPA (ICS). Peut être déduit du
  ///               numéro d'entreprise si non fourni explicitement.
  static SepaBatchResult generate({
    required List<SepaDebit> debits,
    required Map<String, SepaMandate> mandates,
    required CompanyProfile company,
    String? creditorId,
    DateTime? createdAt,
    bool checkPreNotification = true,
  }) {
    final now = createdAt ?? DateTime.now();
    final excluded = <String>[];

    // ── Identifiant créancier ──
    final ics = (creditorId != null && creditorId.trim().isNotEmpty)
        ? creditorId.trim().toUpperCase()
        : SepaValidator.creditorIdFromEnterpriseNumber(company.companyNumber);
    if (ics == null || SepaValidator.validateCreditorId(ics) != null) {
      // Sans ICS valide, la banque refuse le fichier : on refuse de produire
      // un document inutilisable.
      return SepaBatchResult(
        xml: '',
        filename: '',
        included: 0,
        excluded: [
          'Identifiant créancier SEPA (ICS) absent ou invalide. '
              'Vérifiez le numéro d\'entreprise de la société : il doit '
              'comporter 10 chiffres et satisfaire la clé de contrôle BCE. '
              'Sans ICS valide, aucun prélèvement ne peut être déposé.',
        ],
        total: 0,
      );
    }

    // ── Compte de recouvrement du créancier ──
    final creditorIban = SepaValidator.validateIban(company.iban);
    if (!creditorIban.valid) {
      return SepaBatchResult(
        xml: '',
        filename: '',
        included: 0,
        excluded: [
          'IBAN de recouvrement de la société invalide : ${creditorIban.error}',
        ],
        total: 0,
      );
    }
    final creditorBic = SepaValidator.validateBic(company.bic);
    if (creditorBic != null) {
      return SepaBatchResult(
        xml: '',
        filename: '',
        included: 0,
        excluded: ['BIC de la société invalide : $creditorBic'],
        total: 0,
      );
    }

    // ── Filtrage des ordres non prélevables ──
    final valid = <SepaDebit>[];
    for (final d in debits) {
      final m = mandates[d.mandateId];
      if (m == null) {
        excluded.add('${d.clientName} : mandat introuvable (${d.mandateId})');
        continue;
      }
      if (!m.usable) {
        excluded.add(
          '${d.clientName} : mandat « ${m.mandateReference} » non utilisable '
          '(${m.status.label.toLowerCase()})',
        );
        continue;
      }
      if (d.amount <= 0) {
        excluded.add('${d.clientName} : montant nul ou négatif');
        continue;
      }
      if (d.currency.toUpperCase() != 'EUR') {
        excluded.add('${d.clientName} : devise « ${d.currency} » non SEPA');
        continue;
      }
      final ibanCheck = SepaValidator.validateIban(d.iban);
      if (!ibanCheck.valid) {
        excluded.add('${d.clientName} : IBAN du débiteur invalide');
        continue;
      }
      if (checkPreNotification &&
          !d.isPreNotificationCompliant(m.preNotificationDays)) {
        excluded.add(
          '${d.clientName} : pré-notification non conforme — elle doit être '
          'envoyée au moins ${m.preNotificationDays} jours avant le '
          '${_date(d.requestedCollectionDate)}',
        );
        continue;
      }
      if (d.mandateReference != m.mandateReference) {
        excluded.add(
          '${d.clientName} : référence de mandat incohérente avec le mandat',
        );
        continue;
      }
      valid.add(d);
    }

    if (valid.isEmpty) {
      return SepaBatchResult(
        xml: '',
        filename: '',
        included: 0,
        excluded: excluded.isEmpty
            ? ['Aucun ordre de prélèvement à traiter']
            : excluded,
        total: 0,
      );
    }

    // ── Regroupement par (date d'exécution, séquence) ──
    // Obligatoire : un bloc PmtInf ne porte qu'une date et qu'une séquence.
    final groups = <String, List<SepaDebit>>{};
    for (final d in valid) {
      final key =
          '${_date(d.requestedCollectionDate)}|${d.sequenceType.code}';
      groups.putIfAbsent(key, () => []).add(d);
    }
    final sortedKeys = groups.keys.toList()..sort();

    final msgId = _ref35(
      'GRX-${now.millisecondsSinceEpoch}-${now.microsecondsSinceEpoch % 1000}',
    );

    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.008.001.02">',
    );
    buf.writeln('  <CstmrDrctDbtInitn>');
    buf.writeln('    <GrpHdr>');
    buf.writeln('      <MsgId>$msgId</MsgId>');
    buf.writeln('      <CreDtTm>${_dateTime(now)}</CreDtTm>');
    buf.writeln('      <NbOfTxs>${valid.length}</NbOfTxs>');
    final total = valid.fold<double>(0, (s, d) => s + d.amount);
    buf.writeln('      <CtrlSum>${_amount(total)}</CtrlSum>');
    buf.writeln('      <InitgPty>');
    buf.writeln('        <Nm>${_esc(company.legalName)}</Nm>');
    buf.writeln('      </InitgPty>');
    buf.writeln('    </GrpHdr>');

    var block = 0;
    for (final key in sortedKeys) {
      final list = groups[key]!;
      block++;
      final parts = key.split('|');
      final colltnDate = parts[0];
      final seqTp = parts[1];
      final blockTotal = list.fold<double>(0, (s, d) => s + d.amount);

      buf.writeln('    <PmtInf>');
      buf.writeln('      <PmtInfId>$msgId-$block</PmtInfId>');
      buf.writeln('      <PmtMtd>DD</PmtMtd>');
      buf.writeln('      <NbOfTxs>${list.length}</NbOfTxs>');
      buf.writeln('      <CtrlSum>${_amount(blockTotal)}</CtrlSum>');
      buf.writeln('      <PmtTpInf>');
      buf.writeln('        <SvcLvl><Cd>SEPA</Cd></SvcLvl>');
      // Le schéma local vient du mandat : un mandat B2B doit être annoncé
      // « B2B », sinon la banque applique les règles CORE (remboursables).
      buf.writeln(
        '        <LclInstrm><Cd>${mandates[list.first.mandateId]!.type.code}</Cd></LclInstrm>',
      );
      buf.writeln('        <SeqTp>$seqTp</SeqTp>');
      buf.writeln('      </PmtTpInf>');
      buf.writeln('      <ReqdColltnDt>$colltnDate</ReqdColltnDt>');
      buf.writeln('      <Cdtr>');
      buf.writeln('        <Nm>${_esc(company.legalName)}</Nm>');
      buf.writeln('      </Cdtr>');
      buf.writeln('      <CdtrAcct>');
      buf.writeln(
        '        <Id><IBAN>${SepaValidator.normalizeIban(company.iban)}</IBAN></Id>',
      );
      buf.writeln('      </CdtrAcct>');
      buf.writeln('      <CdtrAgt>');
      buf.writeln(
        '        <FinInstnId><BIC>${SepaValidator.normalizeBic(company.bic)}</BIC></FinInstnId>',
      );
      buf.writeln('      </CdtrAgt>');
      buf.writeln('      <ChrgBr>SLEV</ChrgBr>');
      buf.writeln('      <CdtrSchmeId>');
      buf.writeln('        <Id>');
      buf.writeln('          <PrvtId>');
      buf.writeln('            <Othr>');
      buf.writeln('              <Id>$ics</Id>');
      buf.writeln('              <SchmeNm><Prtry>SEPA</Prtry></SchmeNm>');
      buf.writeln('            </Othr>');
      buf.writeln('          </PrvtId>');
      buf.writeln('        </Id>');
      buf.writeln('      </CdtrSchmeId>');

      for (final d in list) {
        final m = mandates[d.mandateId]!;
        buf.writeln('      <DrctDbtTxInf>');
        buf.writeln(
          '        <PmtId><EndToEndId>${_ref35(d.endToEndId)}</EndToEndId></PmtId>',
        );
        buf.writeln(
          '        <InstdAmt Ccy="EUR">${_amount(d.amount)}</InstdAmt>',
        );
        buf.writeln('        <DrctDbtTx>');
        buf.writeln('          <MndtRltdInf>');
        buf.writeln('            <MndtId>${_esc(_ref35(m.mandateReference))}</MndtId>');
        buf.writeln(
          '            <DtOfSgntr>${_date(m.signatureDate)}</DtOfSgntr>',
        );
        buf.writeln('            <AmdmntInd>false</AmdmntInd>');
        buf.writeln('          </MndtRltdInf>');
        buf.writeln('        </DrctDbtTx>');
        buf.writeln('        <DbtrAgt>');
        buf.writeln(
          '          <FinInstnId><Othr><Id>NOTPROVIDED</Id></Othr></FinInstnId>',
        );
        buf.writeln('        </DbtrAgt>');
        buf.writeln('        <Dbtr>');
        buf.writeln('          <Nm>${_esc(_ref35(m.accountHolder))}</Nm>');
        buf.writeln('        </Dbtr>');
        buf.writeln('        <DbtrAcct>');
        buf.writeln(
          '          <Id><IBAN>${SepaValidator.normalizeIban(d.iban)}</IBAN></Id>',
        );
        buf.writeln('        </DbtrAcct>');
        buf.writeln('        <RmtInf>');
        buf.writeln(
          '          <Ustrd>${_esc(_ref35(d.remittanceInformation))}</Ustrd>',
        );
        buf.writeln('        </RmtInf>');
        buf.writeln('      </DrctDbtTxInf>');
      }
      buf.writeln('    </PmtInf>');
    }

    buf.writeln('  </CstmrDrctDbtInitn>');
    buf.writeln('</Document>');

    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return SepaBatchResult(
      xml: buf.toString(),
      filename: 'GOREX-PAIN008-$stamp-${valid.length}.xml',
      included: valid.length,
      excluded: excluded,
      total: total,
    );
  }
}
