import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/billing/vat_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../documents/document_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  FinanceDocType? _filter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    var docs = [...s.financeDocs];
    if (_filter != null) docs = docs.where((d) => d.type == _filter).toList();
    docs.sort((a, b) => b.date.compareTo(a.date));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finance', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Text(
              'Devis · factures · marges · commissions · rentabilité',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : 2;
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                final kpis = [
                  KpiTile(
                    label: 'Chiffre d\'affaires',
                    value: eur.format(s.totalRevenue),
                    icon: Icons.trending_up,
                  ),
                  KpiTile(
                    label: 'Marge totale',
                    value: eur.format(s.totalMargin),
                    icon: Icons.savings_outlined,
                    accent: AppColors.champagne,
                  ),
                  KpiTile(
                    label: 'Dépenses',
                    value: eur.format(s.totalCost),
                    icon: Icons.receipt_outlined,
                    accent: AppColors.greyLight,
                  ),
                  KpiTile(
                    label: 'Solde à encaisser',
                    value: eur.format(s.outstandingBalance),
                    icon: Icons.pending_actions_outlined,
                    accent: AppColors.statusWaiting,
                  ),
                ];
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: kpis
                      .map((k) => SizedBox(width: w, child: k))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            SectionHeader(
              title: 'Documents financiers',
              trailing: GoldButton(
                label: 'Nouveau',
                icon: Icons.add,
                onPressed: () => _newDoc(context, s),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChipLux(
                    label: 'Tous',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  ...FinanceDocType.values.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChipLux(
                        label: t.label,
                        selected: _filter == t,
                        onTap: () =>
                            setState(() => _filter = _filter == t ? null : t),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...docs.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LuxuryCard(
                  onTap: () => _openDoc(context, s, d),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.champagne.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          d.type == FinanceDocType.invoice
                              ? Icons.receipt_long_outlined
                              : d.type == FinanceDocType.quote
                              ? Icons.request_quote_outlined
                              : Icons.payments_outlined,
                          size: 18,
                          color: AppColors.champagne,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.type.label} · ${d.reference}',
                              style: AppTypography.title.copyWith(
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.clientName} · ${DateFormat('dd/MM/yyyy', 'fr_BE').format(d.date)}',
                              style: AppTypography.caption,
                            ),
                            if (d.peppolStatus != PeppolStatus.notApplicable) ...[
                              const SizedBox(height: 5),
                              _peppolPill(d.peppolStatus),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            eur.format(d.total),
                            style: AppTypography.title.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          StatusPill(
                            label: d.status.label,
                            color: d.status.color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(title: 'Dépenses (coûts fournisseurs)'),
            const SizedBox(height: 12),
            ...s.expenses.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LuxuryCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_outlined,
                        size: 16,
                        color: AppColors.greyLight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.label,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.offWhite,
                              ),
                            ),
                            Text(
                              '${e.providerName} · ${e.category}',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '- ${eur.format(e.amount)}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.urgent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Color _peppolColor(PeppolStatus st) {
    switch (st) {
      case PeppolStatus.delivered:
        return AppColors.statusConfirmed;
      case PeppolStatus.sent:
        return AppColors.statusProgress;
      case PeppolStatus.ready:
        return AppColors.champagne;
      case PeppolStatus.failed:
        return AppColors.urgent;
      case PeppolStatus.notApplicable:
        return AppColors.grey;
    }
  }

  Widget _peppolPill(PeppolStatus st) => StatusPill(
    label: 'Peppol · ${st.label}',
    color: _peppolColor(st),
    icon: Icons.send_outlined,
  );

  /// Panneau d'actions d'un document financier :
  /// aperçu PDF, transmission Peppol et confirmation de distribution.
  void _openDoc(BuildContext context, AppState s, FinanceDocument d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${d.type.label} · ${d.reference}',
                style: AppTypography.headline,
              ),
              const SizedBox(height: 4),
              Text(d.clientName, style: AppTypography.caption),
              const SizedBox(height: 14),
              LuxuryCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    InfoRow(label: 'Statut', value: d.status.label),
                    if (d.clientVatNumber != null) ...[
                      const Divider(height: 1),
                      InfoRow(
                        label: 'TVA client',
                        value: VatService.formatVat(d.clientVatNumber!),
                      ),
                    ],
                    if (d.vatMention != null) ...[
                      const Divider(height: 1),
                      InfoRow(label: 'Régime', value: d.vatMention!),
                    ],
                    if (d.structuredCommunication != null) ...[
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Communication',
                        value: d.structuredCommunication!,
                      ),
                    ],
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Peppol',
                      value: d.peppolStatus == PeppolStatus.notApplicable
                          ? 'Non applicable'
                          : d.peppolStatus.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GoldButton(
                label: 'Aperçu / export PDF',
                icon: Icons.picture_as_pdf_outlined,
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  DocumentService.exportFinanceDoc(context, s, d);
                },
              ),
              if (d.peppolStatus != PeppolStatus.notApplicable) ...[
                const SizedBox(height: 10),
                if (d.peppolStatus == PeppolStatus.ready)
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await s.sendViaPeppol(d.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Facture transmise via le réseau Peppol.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_outlined, size: 15),
                    label: const Text('TRANSMETTRE VIA PEPPOL'),
                  ),
                if (d.peppolStatus == PeppolStatus.sent)
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await s.markPeppolDelivered(d.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Accusé Peppol enregistré (distribué).'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.mark_email_read_outlined, size: 15),
                    label: const Text('MARQUER COMME DISTRIBUÉ'),
                  ),
                if (d.peppolStatus == PeppolStatus.delivered)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 15,
                        color: AppColors.statusConfirmed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Facture distribuée via Peppol',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.statusConfirmed,
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _newDoc(BuildContext context, AppState s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: SectionHeader(title: 'Nouveau document'),
            ),
            const Divider(height: 1),
            ...FinanceDocType.values.map(
              (t) => ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.champagne,
                ),
                title: Text(
                  t.label,
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _createDoc(context, s, t);
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _createDoc(BuildContext context, AppState s, FinanceDocType type) {
    final desc = TextEditingController();
    final amount = TextEditingController();
    String? clientId = s.clients.isNotEmpty ? s.clients.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${type.label} — nouveau', style: AppTypography.headline),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: clientId,
                dropdownColor: AppColors.surfaceElevated,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'CLIENT'),
                items: s.clients
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSheet(() => clientId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'DESCRIPTION'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'MONTANT (€)'),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Créer',
                fullWidth: true,
                onPressed: () async {
                  if (desc.text.trim().isEmpty || clientId == null) return;
                  final client = s.clientById(clientId);
                  await s.createFinanceDoc(
                    FinanceDocument(
                      id: '',
                      reference: '',
                      type: type,
                      clientId: clientId!,
                      clientName: client?.fullName ?? 'Client',
                      date: DateTime.now(),
                      dueDate: DateTime.now().add(const Duration(days: 30)),
                      lines: [
                        FinanceLine(
                          description: desc.text.trim(),
                          unitPrice: double.tryParse(amount.text) ?? 0,
                        ),
                      ],
                      status: type == FinanceDocType.quote
                          ? InvoiceStatus.draft
                          : InvoiceStatus.sent,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
