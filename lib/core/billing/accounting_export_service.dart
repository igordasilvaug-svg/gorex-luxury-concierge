import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';

/// Service d'export comptable : journal des ventes (CSV + PDF).
///
/// Produit un fichier exploitable par le comptable de Gorex Group :
/// une ligne par facture avec date, référence, client, TVA, montants,
/// régime de TVA et statut Peppol.
class AccountingExportService {
  AccountingExportService._();

  static final _eur = NumberFormat.currency(
    locale: 'fr_BE',
    symbol: '€',
    decimalDigits: 2,
  );

  /// Construit le contenu CSV du journal des ventes.
  /// Séparateur `;` et décimales `,` (convention belge/Excel).
  static String buildSalesJournalCsv(
    List<FinanceDocument> documents, {
    int? year,
  }) {
    final docs = documents
        .where((d) => d.type == FinanceDocType.invoice)
        .where((d) => year == null || d.date.year == year)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    String dec(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    String d(DateTime? v) =>
        v == null ? '' : DateFormat('dd/MM/yyyy').format(v);
    String esc(String s) => '"${s.replaceAll('"', '""')}"';

    final b = StringBuffer();
    b.writeln(
      'Date;Reference;Client;TVA client;HT;Taux TVA;TVA;TTC;Paye;Solde;'
      'Statut;Regime;Peppol;Echeance',
    );
    for (final doc in docs) {
      b.writeln(
        [
          d(doc.date),
          esc(doc.reference),
          esc(doc.clientName),
          esc(doc.clientVatNumber ?? ''),
          dec(doc.subtotal),
          dec(doc.taxPercent),
          dec(doc.taxAmount),
          dec(doc.total),
          dec(doc.amountPaid),
          dec(doc.balance),
          esc(doc.status.label),
          esc(doc.vatMention ?? ''),
          esc(doc.peppolStatus == PeppolStatus.notApplicable
              ? 'N/A'
              : doc.peppolStatus.label),
          d(doc.dueDate),
        ].join(';'),
      );
    }
    // Totaux
    final ht = docs.fold(0.0, (s, x) => s + x.subtotal);
    final tva = docs.fold(0.0, (s, x) => s + x.taxAmount);
    final ttc = docs.fold(0.0, (s, x) => s + x.total);
    b.writeln(
      '${esc('TOTAUX')};${esc('${docs.length} factures')};;;;'
      '${dec(ht)};;${dec(tva)};${dec(ttc)};;;;;',
    );
    return b.toString();
  }

  /// Génère un PDF du journal des ventes et l'ouvre pour impression/partage.
  static Future<void> exportSalesJournalPdf(
    List<FinanceDocument> documents, {
    required String companyName,
    String? companyVat,
    int? year,
  }) async {
    final docs = documents
        .where((d) => d.type == FinanceDocType.invoice)
        .where((d) => year == null || d.date.year == year)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final gold = PdfColor.fromInt(0xFFC6A15B);
    final dark = PdfColor.fromInt(0xFF111114);
    final grey = PdfColor.fromInt(0xFF6B6B70);
    final line = PdfColor.fromInt(0xFFDDDDDD);

    final doc = pw.Document();
    final ht = docs.fold(0.0, (s, x) => s + x.subtotal);
    final tva = docs.fold(0.0, (s, x) => s + x.taxAmount);
    final ttc = docs.fold(0.0, (s, x) => s + x.total);
    final solde = docs.fold(0.0, (s, x) => s + x.balance);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'GOREX',
                    style: pw.TextStyle(
                      fontSize: 18,
                      letterSpacing: 5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'JOURNAL DES VENTES${year != null ? ' — $year' : ''}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: gold,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontSize: 10, color: dark)),
                  if (companyVat != null && companyVat.isNotEmpty)
                    pw.Text('TVA $companyVat', style: pw.TextStyle(fontSize: 8, color: grey)),
                  pw.Text(
                    'Édité le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 8, color: grey),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 1.2, color: gold),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Référence',
              'Client',
              'TVA client',
              'HT',
              'TVA',
              'TTC',
              'Payé',
              'Solde',
              'Régime',
              'Peppol',
            ],
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              color: gold,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: 7, color: dark),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF6F4EF),
            ),
            border: pw.TableBorder.all(color: line, width: 0.4),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
            data: docs
                .map(
                  (x) => [
                    DateFormat('dd/MM/yy').format(x.date),
                    x.reference,
                    x.clientName,
                    x.clientVatNumber ?? '—',
                    _eur.format(x.subtotal),
                    _eur.format(x.taxAmount),
                    _eur.format(x.total),
                    _eur.format(x.amountPaid),
                    _eur.format(x.balance),
                    x.vatMention ?? '—',
                    x.peppolStatus == PeppolStatus.notApplicable
                        ? 'N/A'
                        : x.peppolStatus.label,
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 300,
              child: pw.Column(
                children: [
                  _total('Total HT', _eur.format(ht), dark, gold),
                  _total('Total TVA', _eur.format(tva), dark, gold),
                  _total('Total TTC', _eur.format(ttc), dark, gold, bold: true),
                  _total('Solde à encaisser', _eur.format(solde), dark, gold),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  static pw.Widget _total(
    String label,
    String value,
    PdfColor dark,
    PdfColor gold, {
    bool bold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: bold ? 10 : 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: dark,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: bold ? 10 : 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? gold : dark,
          ),
        ),
      ],
    ),
  );
}
