import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/billing/accounting_export_service.dart';
import '../../core/billing/reconciliation_service.dart';
import '../../core/billing/reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../settings/reminder_settings_screen.dart';

/// Écran « Comptabilité » : rapprochement bancaire automatique,
/// relances des factures impayées et export comptable (journal des ventes).
class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comptabilité', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Encaissements · relances · export du journal des ventes',
                    style: AppTypography.caption,
                  ),
                ),
                IconButton(
                  tooltip: 'Configuration des relances automatiques',
                  icon: Icon(
                    s.reminderConfig.enabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 18,
                    color: s.reminderConfig.enabled
                        ? AppColors.statusConfirmed
                        : AppColors.grey,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReminderSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),

            // ─────────────── KPIs ───────────────
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : 2;
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                final kpis = [
                  KpiTile(
                    label: 'Encaissé',
                    value: eur.format(s.collectedAmount),
                    icon: Icons.account_balance_wallet_outlined,
                    accent: AppColors.statusConfirmed,
                  ),
                  KpiTile(
                    label: 'Solde à encaisser',
                    value: eur.format(s.outstandingBalance),
                    icon: Icons.pending_actions_outlined,
                    accent: AppColors.statusWaiting,
                  ),
                  KpiTile(
                    label: 'Échu (${s.overdueCount})',
                    value: eur.format(s.overdueAmount),
                    icon: Icons.warning_amber_outlined,
                    accent: AppColors.urgent,
                  ),
                  KpiTile(
                    label: 'Non rapproché',
                    value: eur.format(s.unmatchedAmount),
                    icon: Icons.compare_arrows_outlined,
                    accent: AppColors.champagne,
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
            const SizedBox(height: 24),

            // ─────────────── Onglets ───────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChipLux(
                    label: 'Rapprochement',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  FilterChipLux(
                    label: 'Relances',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 8),
                  FilterChipLux(
                    label: 'Export comptable',
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_tab == 0) _reconciliationTab(context, s, eur),
            if (_tab == 1) _remindersTab(context, s, eur),
            if (_tab == 2) _exportTab(context, s, eur),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════ RAPPROCHEMENT ═══════════════════════
  Widget _reconciliationTab(BuildContext context, AppState s, NumberFormat eur) {
    final txs = [...s.bankTransactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final unmatched = txs.where((t) => !t.matched).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Relevé bancaire',
          subtitle: unmatched == 0
              ? 'Toutes les transactions sont rapprochées.'
              : '$unmatched transaction(s) à rapprocher',
          trailing: GoldButton(
            label: 'Rapprochement auto',
            icon: Icons.auto_awesome,
            onPressed: () async {
              final n = await s.autoReconcile();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      n == 0
                          ? 'Aucun rapprochement automatique possible.'
                          : '$n paiement(s) rapproché(s) automatiquement.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 14),
        if (txs.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'Aucune transaction',
            message:
                'Importez un relevé bancaire pour lancer le rapprochement.',
          ),
        ...txs.map((t) => _txCard(context, s, t, eur)),
      ],
    );
  }

  Widget _txCard(
    BuildContext context,
    AppState s,
    BankTransaction t,
    NumberFormat eur,
  ) {
    final match = ReconciliationService.reconcile(
      t,
      s.financeDocs,
      threshold: 0.4,
    );
    final linked = t.matched
        ? s.financeById(t.matchedDocumentId ?? '')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LuxuryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (t.matched
                            ? AppColors.statusConfirmed
                            : AppColors.champagne)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    t.matched
                        ? Icons.check_circle_outline
                        : Icons.south_west,
                    size: 17,
                    color: t.matched
                        ? AppColors.statusConfirmed
                        : AppColors.champagne,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.counterparty,
                        style: AppTypography.title.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd/MM/yyyy', 'fr_BE').format(t.date)}'
                        '${t.iban != null ? ' · ${t.iban}' : ''}',
                        style: AppTypography.caption,
                      ),
                      if (t.communication.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Comm. : ${t.communication}',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10.5,
                            color: AppColors.greyLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+ ${eur.format(t.amount)}',
                      style: AppTypography.title.copyWith(
                        fontSize: 14,
                        color: AppColors.statusConfirmed,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StatusPill(
                      label: t.matched ? 'Rapproché' : 'À traiter',
                      color: t.matched
                          ? AppColors.statusConfirmed
                          : AppColors.statusWaiting,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (t.matched && linked != null)
              Row(
                children: [
                  const Icon(
                    Icons.link,
                    size: 14,
                    color: AppColors.statusConfirmed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${linked.reference} · ${linked.clientName}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.statusConfirmed,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => s.unmatchTransaction(t.id),
                    child: const Text('Détacher'),
                  ),
                ],
              )
            else ...[
              if (match.matched)
                _suggestion(context, s, t, match, eur)
              else
                Row(
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 14,
                      color: AppColors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucune correspondance fiable — rapprochement manuel requis.',
                        style: AppTypography.caption,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _manualMatch(context, s, t),
                      child: const Text('Associer'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestion(
    BuildContext context,
    AppState s,
    BankTransaction t,
    ReconciliationMatch match,
    NumberFormat eur,
  ) {
    final d = match.document!;
    final pct = (match.confidence * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.champagne.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.champagneDark.withValues(alpha: 0.4),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: AppColors.champagne),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestion · ${d.reference} (${d.clientName})',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.offWhite,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  '${match.method.label} · confiance $pct % · solde ${eur.format(d.balance)}',
                  style: AppTypography.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await s.reconcileTransaction(t.id, d.id, method: match.method);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${d.reference} rapprochée et soldée.'),
                  ),
                );
              }
            },
            child: const Text('Rapprocher'),
          ),
        ],
      ),
    );
  }

  void _manualMatch(BuildContext context, AppState s, BankTransaction t) {
    final invoices = s.financeDocs
        .where(
          (d) =>
              d.type == FinanceDocType.invoice &&
              d.status != InvoiceStatus.paid &&
              d.status != InvoiceStatus.cancelled,
        )
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: SectionHeader(title: 'Rapprocher manuellement'),
            ),
            const Divider(height: 1),
            if (invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune facture ouverte.'),
              ),
            ...invoices.map(
              (d) => ListTile(
                leading: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.champagne,
                ),
                title: Text(
                  '${d.reference} · ${d.clientName}',
                  style: AppTypography.title.copyWith(fontSize: 13.5),
                ),
                subtitle: Text(
                  'Solde ${NumberFormat.currency(locale: 'fr_BE', symbol: '€', decimalDigits: 2).format(d.balance)}',
                  style: AppTypography.caption,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await s.reconcileTransaction(
                    t.id,
                    d.id,
                    method: PaymentMatchMethod.manual,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════ RELANCES ═══════════════════════
  Widget _remindersTab(BuildContext context, AppState s, NumberFormat eur) {
    final overdue = s.overdueInvoices;
    final due = ReminderService.pending(
      s.financeDocs,
      minDays: s.reminderConfig.minDaysBetween,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.reminderConfig.enabled) _autoReminderBanner(context, s),
        SectionHeader(
          title: 'Factures échues',
          subtitle: overdue.isEmpty
              ? 'Aucune facture en retard — tout est sous contrôle.'
              : '${overdue.length} facture(s) en retard · '
                    '${due.length} relance(s) à envoyer',
          trailing: overdue.isEmpty
              ? null
              : GoldButton(
                  label: 'Relancer tout',
                  icon: Icons.outgoing_mail,
                  onPressed: () async {
                    final n = await s.sendAllDueReminders();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            n == 0
                                ? 'Aucune relance à envoyer.'
                                : '$n relance(s) envoyée(s).',
                          ),
                        ),
                      );
                    }
                  },
                ),
        ),
        const SizedBox(height: 14),
        if (overdue.isEmpty)
          const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'Aucun impayé',
            message:
                'Les factures échues apparaîtront ici avec leur niveau de relance.',
          ),
        ...overdue.map((d) => _reminderCard(context, s, d, eur)),
      ],
    );
  }

  Widget _autoReminderBanner(BuildContext context, AppState s) {
    final cfg = s.reminderConfig;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.statusConfirmed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.statusConfirmed.withValues(alpha: 0.35),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 16,
              color: AppColors.statusConfirmed,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cfg.autoSend
                    ? 'Relance automatique active · toutes les ${cfg.intervalHours} h'
                    : 'Détection automatique active (envoi manuel)',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.offWhite,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final n = await s.runAutoReminders(force: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        n == 0
                            ? 'Aucune relance à envoyer.'
                            : '$n relance(s) traitée(s).',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Exécuter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCard(
    BuildContext context,
    AppState s,
    FinanceDocument d,
    NumberFormat eur,
  ) {
    final plan = ReminderService.plan(d);
    final target = plan.nextLevel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LuxuryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.reference} · ${d.clientName}',
                        style: AppTypography.title.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Échue le ${DateFormat('dd/MM/yyyy', 'fr_BE').format(d.dueDate ?? d.date)}'
                        ' · ${d.daysOverdue} j de retard',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.urgent,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      eur.format(d.balance),
                      style: AppTypography.title.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    StatusPill(
                      label: d.reminderLevel == ReminderLevel.none
                          ? 'À relancer'
                          : d.reminderLevel.label,
                      color: d.reminderLevel == ReminderLevel.finalNotice
                          ? AppColors.urgent
                          : d.reminderLevel == ReminderLevel.none
                          ? AppColors.statusWaiting
                          : AppColors.champagne,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.reason,
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _previewReminder(context, s, d, target),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('APERÇU'),
                ),
                const SizedBox(width: 8),
                if (plan.due)
                  GoldButton(
                    label: 'Relancer',
                    icon: Icons.send_outlined,
                    onPressed: () async {
                      await s.sendReminder(d.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Relance ${target.label} envoyée à ${d.clientName}.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _previewReminder(
    BuildContext context,
    AppState s,
    FinanceDocument d,
    ReminderLevel level,
  ) {
    final mail = s.buildReminderEmail(d, level);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Relance — ${d.reference}', style: AppTypography.headline),
              const SizedBox(height: 4),
              Text(
                'Objet : ${mail.subject}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.champagne,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blackSoft,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.divider, width: 0.6),
                ),
                child: SelectableText(
                  mail.body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.greyLight,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: '${mail.subject}\n\n${mail.body}',
                          ),
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Relance copiée dans le presse-papier.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 15),
                      label: const Text('COPIER'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GoldButton(
                      label: 'Envoyer',
                      icon: Icons.send_outlined,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await s.sendReminder(d.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Relance ${level.label} enregistrée.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════ EXPORT ═══════════════════════
  Widget _exportTab(BuildContext context, AppState s, NumberFormat eur) {
    final year = DateTime.now().year;
    final journal = s.salesJournal();
    final yearJournal = s.salesJournal(year: year);
    final ht = journal.fold(0.0, (a, d) => a + d.subtotal);
    final tva = journal.fold(0.0, (a, d) => a + d.taxAmount);
    final ttc = journal.fold(0.0, (a, d) => a + d.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Journal des ventes'),
        const SizedBox(height: 14),
        LuxuryCard(
          child: Column(
            children: [
              InfoRow(
                label: 'Factures',
                value: '${journal.length} (exercice $year : ${yearJournal.length})',
              ),
              const Divider(height: 1),
              InfoRow(label: 'Total HT', value: eur.format(ht)),
              const Divider(height: 1),
              InfoRow(label: 'Total TVA', value: eur.format(tva)),
              const Divider(height: 1),
              InfoRow(label: 'Total TTC', value: eur.format(ttc)),
              const Divider(height: 1),
              InfoRow(
                label: 'Émetteur',
                value: s.company.brandName.isNotEmpty
                    ? s.company.brandName
                    : s.company.legalName,
              ),
              const Divider(height: 1),
              InfoRow(label: 'TVA émetteur', value: s.company.vatNumber),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GoldButton(
                label: 'Export PDF',
                icon: Icons.picture_as_pdf_outlined,
                fullWidth: true,
                onPressed: () => AccountingExportService.exportSalesJournalPdf(
                  s.financeDocs,
                  companyName: s.company.brandName.isNotEmpty
                      ? s.company.brandName
                      : s.company.legalName,
                  companyVat: s.company.vatNumber,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _previewCsv(context, s),
                icon: const Icon(Icons.table_chart_outlined, size: 15),
                label: const Text('EXPORT CSV'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Le journal des ventes regroupe toutes les factures avec leur régime '
          'de TVA, statut Peppol et solde — prêt à transmettre à votre '
          'comptable (format belge : séparateur « ; », décimales « , »).',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  void _previewCsv(BuildContext context, AppState s) {
    final csv = AccountingExportService.buildSalesJournalCsv(s.financeDocs);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Journal des ventes — CSV', style: AppTypography.headline),
              const SizedBox(height: 4),
              Text(
                'gorex_journal_ventes.csv',
                style: AppTypography.caption.copyWith(
                  color: AppColors.champagne,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blackSoft,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.divider, width: 0.6),
                ),
                child: SelectableText(
                  csv,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: AppColors.greyLight,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GoldButton(
                label: 'Copier le CSV',
                icon: Icons.copy_all_outlined,
                fullWidth: true,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('CSV copié dans le presse-papier.'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
