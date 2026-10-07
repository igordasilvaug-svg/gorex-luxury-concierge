import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../documents/document_service.dart';

class ClientInvoicesScreen extends StatelessWidget {
  const ClientInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final docs = client != null
        ? (s.financeForClient(client.id)
            ..sort((a, b) => b.date.compareTo(a.date)))
        : [];
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Factures & documents', style: AppTypography.title),
      ),
      body: SafeArea(
        child: docs.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aucun document',
                message: 'Vos factures et devis apparaîtront ici.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  return LuxuryCard(
                    onTap: () =>
                        DocumentService.exportFinanceDoc(context, s, d),
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
                                DateFormat(
                                  'dd MMM yyyy',
                                  'fr_BE',
                                ).format(d.date),
                                style: AppTypography.caption,
                              ),
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
                  );
                },
              ),
      ),
    );
  }
}

class ClientAgendaScreen extends StatelessWidget {
  const ClientAgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final items = client != null
        ? (s
              .appointmentsForClient(client.id)
              .where((a) => a.end.isAfter(DateTime.now()))
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start)))
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(title: Text('Mon agenda', style: AppTypography.title)),
      body: SafeArea(
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Agenda vide',
                message: 'Vos rendez-vous et voyages apparaîtront ici.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final a = items[i];
                  return LuxuryCard(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.anthracite,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: AppColors.divider,
                              width: 0.6,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('dd', 'fr_BE').format(a.start),
                                style: AppTypography.title.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'MMM',
                                  'fr_BE',
                                ).format(a.start).toUpperCase(),
                                style: AppTypography.eyebrow.copyWith(
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: AppTypography.title.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${DateFormat('EEEE dd MMMM · HH:mm', 'fr_BE').format(a.start)}'
                                '${a.location != null ? ' · ${a.location}' : ''}',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(a.type.icon, size: 16, color: AppColors.champagne),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
