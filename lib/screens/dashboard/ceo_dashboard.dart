import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/animations.dart';
import '../../widgets/common.dart';
import '../requests/request_detail_screen.dart';

class CeoDashboard extends StatelessWidget {
  const CeoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    final urgent = s.requests
        .where(
          (r) => r.urgency.weight >= 2 && r.status != RequestStatus.completed,
        )
        .toList();

    return _DashboardScaffold(
      title: 'Tableau de bord — Direction',
      subtitle: 'Vue consolidée du groupe · Confidentialité maximale',
      children: [
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: _kpiGrid(context, s, eur),
        ),
        const SizedBox(height: 22),
        if (urgent.isNotEmpty) ...[
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: _urgentSection(context, s, urgent),
          ),
          const SizedBox(height: 22),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 260),
          child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 780;
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _domainBreakdown(s),
                const SizedBox(height: 18),
                _conciergePerformance(s),
              ],
            );
            final right = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topClients(context, s, eur),
                const SizedBox(height: 18),
                _pipeline(s),
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 18),
                  Expanded(child: right),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 18), right],
            );
          },
        ),
        ),
      ],
    );
  }

  Widget _kpiGrid(BuildContext context, AppState s, NumberFormat eur) {
    final kpis = [
      KpiTile(
        label: 'Clients actifs',
        value: '${s.activeClients}',
        icon: Icons.people_outline,
        delta: '${s.tiers.length} formules',
      ),
      KpiTile(
        label: 'Demandes ouvertes',
        value: '${s.openRequests}',
        icon: Icons.inbox_outlined,
        delta: '${s.requests.length} total',
      ),
      KpiTile(
        label: 'Demandes urgentes',
        value: '${s.urgentRequests}',
        icon: Icons.priority_high,
        accent: AppColors.urgent,
        delta: s.urgentRequests > 0 ? 'Action requise' : 'OK',
      ),
      KpiTile(
        label: 'Réservations',
        value: '${s.bookings.length}',
        icon: Icons.event_available_outlined,
        delta: '${s.bookings.where((b) => b.confirmed).length} confirmées',
      ),
      KpiTile(
        label: 'Chiffre d\'affaires',
        value: eur.format(s.totalRevenue),
        icon: Icons.trending_up,
        delta: 'HT',
        valueWidget: GoldCountUp(
          value: s.totalRevenue,
          formatter: (v) => eur.format(v),
          style: AppTypography.numberLarge.copyWith(fontSize: 26),
        ),
      ),
      KpiTile(
        label: 'Marge',
        value: eur.format(s.totalMargin),
        icon: Icons.savings_outlined,
        delta: s.totalRevenue > 0
            ? '${(s.totalMargin / s.totalRevenue * 100).toStringAsFixed(0)}%'
            : '—',
        valueWidget: GoldCountUp(
          value: s.totalMargin,
          formatter: (v) => eur.format(v),
          style: AppTypography.numberLarge.copyWith(fontSize: 26),
        ),
      ),
      KpiTile(
        label: 'Dépenses',
        value: eur.format(s.totalCost),
        icon: Icons.receipt_outlined,
        accent: AppColors.greyLight,
        valueWidget: GoldCountUp(
          value: s.totalCost,
          formatter: (v) => eur.format(v),
          style: AppTypography.numberLarge.copyWith(fontSize: 26),
        ),
      ),
      KpiTile(
        label: 'Commissions',
        value: eur.format(s.totalCommissions),
        icon: Icons.percent,
        accent: AppColors.champagne,
        valueWidget: GoldCountUp(
          value: s.totalCommissions,
          formatter: (v) => eur.format(v),
          style: AppTypography.numberLarge.copyWith(fontSize: 26),
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1000 ? 4 : (c.maxWidth > 620 ? 3 : 2);
        final w = (c.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: kpis.map((k) => SizedBox(width: w, child: k)).toList(),
        );
      },
    );
  }

  Widget _urgentSection(BuildContext context, AppState s, List urgent) {
    return LuxuryCard(
      highlighted: true,
      borderColor: AppColors.urgent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.urgent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'DEMANDES URGENTES / PRIORITAIRES',
                style: AppTypography.eyebrow.copyWith(color: AppColors.urgent),
              ),
              const Spacer(),
              StatusPill(label: '${urgent.length}', color: AppColors.urgent),
            ],
          ),
          const SizedBox(height: 14),
          ...urgent.map((r) => _UrgentRow(request: r)),
        ],
      ),
    );
  }

  Widget _domainBreakdown(AppState s) {
    final byDomain = s.requestsByDomain;
    final max = byDomain.values.fold<int>(1, (a, b) => b > a ? b : a);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Demandes par catégorie'),
          const SizedBox(height: 16),
          ...ServiceDomain.values.map((d) {
            final v = byDomain[d] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(d.icon, size: 14, color: AppColors.champagne),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          d.label,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.offWhite,
                          ),
                        ),
                      ),
                      Text(
                        '$v',
                        style: AppTypography.title.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: v / max,
                      minHeight: 4,
                      backgroundColor: AppColors.anthracite,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.champagneDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _conciergePerformance(AppState s) {
    final perf = s.conciergePerformance;
    final entries = perf.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Performance des concierges',
            subtitle: 'Demandes assignées',
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('Aucune assignation', style: AppTypography.caption)
          else
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    InitialsAvatar(initials: _initials(e.key), size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.key,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.offWhite,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value}',
                      style: AppTypography.title.copyWith(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text('demandes', style: AppTypography.caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topClients(BuildContext context, AppState s, NumberFormat eur) {
    final clients = s.topClients.take(5).toList();
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Clients VIP',
            subtitle: 'Par valeur de contrat',
          ),
          const SizedBox(height: 14),
          ...clients.map((c) {
            final tier = s.tierById(c.subscriptionTierId);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  InitialsAvatar(initials: _initials(c.fullName), size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.offWhite,
                          ),
                        ),
                        Text(
                          '${c.code} · ${tier?.name ?? ''}',
                          style: AppTypography.caption.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    eur.format(s.clientValue(c.id)),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagne,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _pipeline(AppState s) {
    final byStage = <ProspectStage, int>{};
    for (final p in s.prospects) {
      byStage[p.stage] = (byStage[p.stage] ?? 0) + 1;
    }
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Pipeline CRM', subtitle: 'Prospects'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProspectStage.values.map((st) {
              return StatusPill(
                label: '${st.label} ${byStage[st] ?? 0}',
                color: st.color,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _UrgentRow extends StatelessWidget {
  final dynamic request;
  const _UrgentRow({required this.request});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(requestId: request.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(width: 3, height: 34, color: request.urgency.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.offWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.reference} · ${request.clientName}',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            StatusPill(label: request.status.code, color: request.status.color),
          ],
        ),
      ),
    );
  }
}

/// Scaffold partagé des dashboards
class _DashboardScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _DashboardScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeSlideIn(
              child: Text(title, style: AppTypography.displayMedium),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: Text(subtitle, style: AppTypography.caption),
            ),
            const SizedBox(height: 10),
            const GoldLineGrow(width: 60),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}
