import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/crm_agenda.dart';
import 'audit_insights.dart';

/// Export PDF du journal d'audit (traçabilité / conformité RGPD).
///
/// Produit un document horodaté listant les actions sensibles, avec un
/// récapitulatif par catégorie. Destiné aux revues de sécurité et à
/// l'archivage interne de Gorex Group.
class AuditExportService {
  AuditExportService._();

  static Future<void> exportPdf(
    List<AuditEntry> entries, {
    required String companyName,
  }) async {
    final insights = AuditInsights(entries);
    final gold = PdfColor.fromInt(0xFFC6A15B);
    final dark = PdfColor.fromInt(0xFF111114);
    final grey = PdfColor.fromInt(0xFF6B6B70);
    final line = PdfColor.fromInt(0xFFDDDDDD);
    final urgent = PdfColor.fromInt(0xFFB03A3A);

    final sorted = [...entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final byCat = insights.byCategory();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'GOREX LUXURY CONCIERGE — Document confidentiel',
              style: pw.TextStyle(fontSize: 7, color: grey),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: grey),
            ),
          ],
        ),
        build: (ctx) => [
          // ── En-tête ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                    'JOURNAL D\'AUDIT',
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
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(fontSize: 10, color: dark),
                  ),
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

          // ── Récapitulatif ──
          pw.Row(
            children: [
              _stat('Entrées', '${insights.total}', dark, gold),
              pw.SizedBox(width: 10),
              _stat('Aujourd\'hui', '${insights.todayCount}', dark, gold),
              pw.SizedBox(width: 10),
              _stat('7 jours', '${insights.last7Count}', dark, gold),
              pw.SizedBox(width: 10),
              _stat('Acteurs', '${insights.activeActorsCount}', dark, gold),
            ],
          ),
          pw.SizedBox(height: 14),

          pw.Text(
            'RÉPARTITION PAR CATÉGORIE',
            style: pw.TextStyle(
              fontSize: 8.5,
              letterSpacing: 1.5,
              color: gold,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in byCat.entries)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: line, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    '${AuditInsights.categoryLabel(e.key)}  ·  ${e.value}',
                    style: pw.TextStyle(fontSize: 8, color: dark),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Tableau détaillé ──
          pw.Text(
            'DÉTAIL DES ÉVÉNEMENTS (${sorted.length})',
            style: pw.TextStyle(
              fontSize: 8.5,
              letterSpacing: 1.5,
              color: gold,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Horodatage',
              'Acteur',
              'Rôle',
              'Action',
              'Cible',
              'Détail',
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
            columnWidths: {
              0: const pw.FixedColumnWidth(78),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.4),
            },
            data: sorted
                .map(
                  (e) => [
                    DateFormat('dd/MM/yy HH:mm').format(e.timestamp),
                    e.actor,
                    e.actorRole,
                    e.action,
                    e.target,
                    e.detail ?? '—',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: urgent, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Document confidentiel — à usage interne uniquement. '
                    'Le journal d\'audit est conservé localement sur l\'appareil '
                    'et n\'est jamais transmis à des tiers.',
                    style: pw.TextStyle(fontSize: 7, color: urgent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (f) => doc.save());
  }

  static pw.Widget _stat(
    String label,
    String value,
    PdfColor dark,
    PdfColor gold,
  ) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: gold, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: dark,
            ),
          ),
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(fontSize: 7, color: gold, letterSpacing: 1),
          ),
        ],
      ),
    ),
  );
}
