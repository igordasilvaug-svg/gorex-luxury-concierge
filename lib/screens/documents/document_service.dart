import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../models/itinerary.dart';
import '../../models/service_request.dart';
import '../../state/app_state.dart';

/// Génération de documents PDF premium (GOREX LUXURY CONCIERGE)
class DocumentService {
  DocumentService._();

  static final _gold = PdfColor.fromInt(0xFFC6A15B);
  static final _dark = PdfColor.fromInt(0xFF111114);
  static final _grey = PdfColor.fromInt(0xFF6B6B70);
  static final _line = PdfColor.fromInt(0xFFDDDDDD);
  static final _eur = NumberFormat.currency(
    locale: 'fr_BE',
    symbol: '€',
    decimalDigits: 2,
  );

  static pw.Widget _header(String docType, String reference) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GOREX',
                  style: pw.TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'LUXURY CONCIERGE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    letterSpacing: 3,
                    color: _grey,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  docType.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 13,
                    letterSpacing: 2,
                    color: _gold,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  reference,
                  style: pw.TextStyle(fontSize: 9, color: _grey),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1.2, color: _gold),
        pw.SizedBox(height: 4),
        pw.Text(
          'Gorex Group SA · Bruxelles, Belgique · concierge@gorex.com · +32 2 555 01 00',
          style: pw.TextStyle(fontSize: 7.5, color: _grey),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Container(height: 0.8, color: _line),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DISCRETION. ACCESS. EXCELLENCE.',
              style: pw.TextStyle(
                fontSize: 7,
                letterSpacing: 1.5,
                color: _gold,
              ),
            ),
            pw.Text(
              'Document confidentiel · Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _grey),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            k.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7.5,
              letterSpacing: 0.8,
              color: _grey,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(v, style: pw.TextStyle(fontSize: 9.5, color: _dark)),
        ),
      ],
    ),
  );

  static pw.Widget _sectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
    child: pw.Text(
      t.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        letterSpacing: 1.6,
        color: _gold,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  // ─────────────────── RÉCAPITULATIF DE DEMANDE ───────────────────
  static Future<void> exportRequestSummary(
    BuildContext context,
    AppState s,
    ServiceRequest r,
  ) async {
    final client = s.clientById(r.clientId);
    final tier = s.tierById(client?.subscriptionTierId);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        footer: _footer,
        build: (ctx) => [
          _header('Récapitulatif de demande', r.reference),
          pw.Text(
            r.title,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _kv('Client', r.clientName),
          if (client != null) _kv('Code client', client.code),
          if (tier != null) _kv('Abonnement', tier.name),
          _kv('Domaine', r.domain.label),
          _kv('Prestation', r.subService),
          _kv(
            'Date',
            '${DateFormat('dd MMMM yyyy', 'fr_BE').format(r.date)} à ${r.time}',
          ),
          _kv('Localisation', r.location),
          _kv('Urgence', r.urgency.label),
          _kv('Statut', r.status.code),
          _kv('Responsable', r.responsibleName ?? 'Non assigné'),
          _kv('Budget', _eur.format(r.budget)),
          if (r.isSecurityEscalated)
            _kv('Sécurité', 'Transmis à GOREX SECURITY'),
          _sectionTitle('Description'),
          pw.Text(
            r.description,
            style: pw.TextStyle(fontSize: 9.5, color: _dark),
          ),
          if (r.history.isNotEmpty) ...[
            _sectionTitle('Historique'),
            ...r.history.map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 95,
                      child: pw.Text(
                        DateFormat('dd/MM/yy HH:mm').format(h.timestamp),
                        style: pw.TextStyle(fontSize: 8, color: _grey),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        '${h.action} — ${h.actor}${h.detail != null ? ' (${h.detail})' : ''}',
                        style: pw.TextStyle(fontSize: 8.5, color: _dark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  // ─────────────────── ITINÉRAIRE PREMIUM ───────────────────
  static Future<void> exportItinerary(
    BuildContext context,
    AppState s,
    Itinerary it,
  ) async {
    final client = s.clientById(it.clientId);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        footer: _footer,
        build: (ctx) => [
          _header('Itinéraire premium', it.reference),
          pw.Text(
            it.title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${it.destination} · ${DateFormat('dd MMM', 'fr_BE').format(it.startDate)} — ${DateFormat('dd MMM yyyy', 'fr_BE').format(it.endDate)}',
            style: pw.TextStyle(fontSize: 10, color: _grey),
          ),
          pw.SizedBox(height: 12),
          _kv('Client', it.clientName),
          if (client != null) _kv('Code client', client.code),
          if (it.flightInfo != null) _kv('Vol', it.flightInfo!),
          if (it.hotelInfo != null) _kv('Hébergement', it.hotelInfo!),
          if (it.transferInfo != null) _kv('Transferts', it.transferInfo!),
          if (it.securityIncluded)
            _kv('Sécurité', 'Coordination GOREX SECURITY'),
          _sectionTitle('Programme'),
          ...it.items.map(
            (item) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line, width: 0.6),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item.day} · ${item.time}',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1,
                          color: _gold,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        item.domain.label,
                        style: pw.TextStyle(fontSize: 7.5, color: _grey),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    item.title,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    item.description,
                    style: pw.TextStyle(fontSize: 9, color: _dark),
                  ),
                  if (item.contact != null) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Contact : ${item.contact}',
                      style: pw.TextStyle(fontSize: 8, color: _grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (it.contacts.isNotEmpty) ...[
            _sectionTitle('Contacts'),
            ...it.contacts.map(
              (c) => pw.Text(
                '• $c',
                style: pw.TextStyle(fontSize: 9, color: _dark),
              ),
            ),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  // ─────────────────── FACTURE / DEVIS ───────────────────
  static Future<void> exportFinanceDoc(
    BuildContext context,
    AppState s,
    FinanceDocument f,
  ) async {
    final client = s.clientById(f.clientId);
    final doc = pw.Document();
    final title = f.type == FinanceDocType.quote ? 'Devis' : 'Facture';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        footer: _footer,
        build: (ctx) => [
          _header(title, f.reference),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ÉMETTEUR',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      letterSpacing: 1,
                      color: _grey,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'GOREX LUXURY CONCIERGE',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Gorex Group SA',
                    style: pw.TextStyle(fontSize: 9, color: _dark),
                  ),
                  pw.Text(
                    'Bruxelles, Belgique',
                    style: pw.TextStyle(fontSize: 9, color: _dark),
                  ),
                  pw.Text(
                    'TVA BE 0000.000.000',
                    style: pw.TextStyle(fontSize: 8, color: _grey),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CLIENT',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      letterSpacing: 1,
                      color: _grey,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    f.clientName,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (client != null)
                    pw.Text(
                      client.code,
                      style: pw.TextStyle(fontSize: 9, color: _dark),
                    ),
                  if (client != null)
                    pw.Text(
                      '${client.city}, ${client.country}',
                      style: pw.TextStyle(fontSize: 9, color: _dark),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          _kv('Date', DateFormat('dd MMMM yyyy', 'fr_BE').format(f.date)),
          if (f.dueDate != null)
            _kv(
              'Échéance',
              DateFormat('dd MMMM yyyy', 'fr_BE').format(f.dueDate!),
            ),
          _kv('Statut', f.status.label),
          _sectionTitle('Détail'),
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Qté', 'Prix unitaire', 'Total'],
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              color: _gold,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: 9, color: _dark),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF6F4EF),
            ),
            border: pw.TableBorder.all(color: _line, width: 0.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            data: f.lines
                .map(
                  (l) => [
                    l.description,
                    l.quantity.toStringAsFixed(0),
                    _eur.format(l.unitPrice),
                    _eur.format(l.total),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _totalRow('Sous-total', _eur.format(f.subtotal)),
                  _totalRow(
                    'TVA ${f.taxPercent.toStringAsFixed(0)}%',
                    _eur.format(f.taxAmount),
                  ),
                  pw.Container(
                    height: 0.8,
                    color: _gold,
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  ),
                  _totalRow('TOTAL', _eur.format(f.total), bold: true),
                  if (f.amountPaid > 0)
                    _totalRow('Payé', _eur.format(f.amountPaid)),
                  if (f.amountPaid > 0)
                    _totalRow('Solde', _eur.format(f.balance), bold: true),
                ],
              ),
            ),
          ),
          if (f.notes != null) ...[
            _sectionTitle('Notes'),
            pw.Text(f.notes!, style: pw.TextStyle(fontSize: 9, color: _dark)),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Merci de votre confiance. Paiement par virement — IBAN BE00 0000 0000 0000.',
            style: pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: bold ? 10 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: _dark,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: bold ? 10 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: bold ? _gold : _dark,
              ),
            ),
          ],
        ),
      );

  // ─────────────────── FICHE CLIENT ───────────────────
  static Future<void> exportClientFile(
    BuildContext context,
    AppState s,
    dynamic client,
  ) async {
    final tier = s.tierById(client.subscriptionTierId);
    final concierge = s.userById(client.assignedConciergeId);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        footer: _footer,
        build: (ctx) => [
          _header('Fiche client confidentielle', client.code),
          pw.Text(
            client.fullName,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          if (client.companyName != null)
            pw.Text(
              client.companyName,
              style: pw.TextStyle(fontSize: 10, color: _grey),
            ),
          pw.SizedBox(height: 12),
          _kv('Catégorie', client.category.label),
          _kv('Confidentialité', client.confidentiality.label),
          _kv('Abonnement', tier?.name ?? '—'),
          _kv('Langue', client.language),
          _kv('Pays / Ville', '${client.country} · ${client.city}'),
          _kv('E-mail', client.email),
          _kv('Téléphone', client.phone),
          if (client.personalAssistant != null)
            _kv(
              'Assistant(e)',
              '${client.personalAssistant} ${client.assistantPhone ?? ''}',
            ),
          _kv('Concierge dédié', concierge?.fullName ?? '—'),
          if (client.preferredHotels.isNotEmpty) ...[
            _sectionTitle('Hôtels préférés'),
            ...client.preferredHotels.map(
              (e) => pw.Text(
                '• $e',
                style: pw.TextStyle(fontSize: 9, color: _dark),
              ),
            ),
          ],
          if (client.preferredRestaurants.isNotEmpty) ...[
            _sectionTitle('Restaurants préférés'),
            ...client.preferredRestaurants.map(
              (e) => pw.Text(
                '• $e',
                style: pw.TextStyle(fontSize: 9, color: _dark),
              ),
            ),
          ],
          if (client.travelPreferences.isNotEmpty) ...[
            _sectionTitle('Préférences de voyage'),
            ...client.travelPreferences.map(
              (e) => pw.Text(
                '• $e',
                style: pw.TextStyle(fontSize: 9, color: _dark),
              ),
            ),
          ],
          if (client.dietaryPreferences.isNotEmpty) ...[
            _sectionTitle('Préférences alimentaires'),
            ...client.dietaryPreferences.map(
              (e) => pw.Text(
                '• $e',
                style: pw.TextStyle(fontSize: 9, color: _dark),
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF6F4EF),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              'Document strictement confidentiel. Diffusion restreinte. Conforme RGPD.',
              style: pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }
}
