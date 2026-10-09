import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/audit/audit_export_service.dart';
import '../../core/audit/audit_insights.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/crm_agenda.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Tableau de bord sécurité — vue synthétique de l'activité et des alertes.
///
/// S'appuie sur le journal d'audit pour présenter : activité quotidienne
/// (14 jours), répartition par catégorie d'actions, indicateurs clés et
/// liste des événements sensibles (échecs, suppressions, escalades…).
class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() =>
      _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  bool _exporting = false;

  Future<void> _exportPdf(List<AuditEntry> entries) async {
    setState(() => _exporting = true);
    try {
      final s = context.read<AppState>();
      await AuditExportService.exportPdf(
        entries,
        companyName: s.company.brandName.isNotEmpty
            ? s.company.brandName
            : s.company.legalName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export PDF indisponible sur cet appareil.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final insights = AuditInsights(state.auditLog);
    final daily = insights.daily(14);
    final byCat = insights.byCategory();
    final sensitive = insights.sensitiveEvents;
    final maxDaily = daily.fold<int>(1, (m, d) => d.count > m ? d.count : m);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord sécurité'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Rapport PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: state.auditLog.isEmpty
                  ? null
                  : () => _exportPdf(state.auditLog),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Sécurité & conformité'),
                  const SizedBox(height: 10),
                  Text(
                    'Tableau de bord sécurité',
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vue consolidée de l\'activité et des événements sensibles. '
                    'Données locales, jamais transmises à des tiers.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 18),

                  // ── KPI ──
                  Row(
                    children: [
                      Expanded(
                        child: KpiTile(
                          label: 'Entrées totales',
                          value: '${insights.total}',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiTile(
                          label: 'Aujourd\'hui',
                          value: '${insights.todayCount}',
                          icon: Icons.today_outlined,
                          accent: AppColors.statusProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: KpiTile(
                          label: '7 derniers jours',
                          value: '${insights.last7Count}',
                          icon: Icons.date_range_outlined,
                          accent: AppColors.statusConfirmed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KpiTile(
                          label: 'Acteurs actifs',
                          value: '${insights.activeActorsCount}',
                          icon: Icons.groups_outlined,
                          accent: AppColors.champagne,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Activité 14 jours ──
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.insights,
                              size: 18,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Activité — 14 derniers jours',
                              style: AppTypography.title,
                            ),
                            const Spacer(),
                            Text(
                              'max $maxDaily/jour',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final d in daily)
                                Expanded(
                                  child: _Bar(
                                    value: d.count,
                                    max: maxDaily,
                                    label: DateFormat('dd').format(d.day),
                                    isToday: _isToday(d.day),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Répartition par catégorie ──
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pie_chart_outline,
                              size: 18,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Répartition par catégorie',
                              style: AppTypography.title,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (byCat.isEmpty)
                          Text('Aucune donnée.', style: AppTypography.caption)
                        else
                          for (final e in byCat.entries) ...[
                            _CategoryRow(
                              label: AuditInsights.categoryLabel(e.key),
                              count: e.value,
                              total: insights.total,
                              color: _catColor(e.key),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Événements sensibles ──
                  LuxuryCard(
                    borderColor: sensitive.isEmpty
                        ? null
                        : AppColors.urgent.withValues(alpha: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              sensitive.isEmpty
                                  ? Icons.verified_user_outlined
                                  : Icons.gpp_maybe_outlined,
                              size: 18,
                              color: sensitive.isEmpty
                                  ? AppColors.statusConfirmed
                                  : AppColors.urgent,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Événements sensibles',
                              style: AppTypography.title,
                            ),
                            const Spacer(),
                            StatusPill(
                              label: '${sensitive.length}',
                              color: sensitive.isEmpty
                                  ? AppColors.statusConfirmed
                                  : AppColors.urgent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (sensitive.isEmpty)
                          Text(
                            'Aucun événement sensible détecté. '
                            'Aucun échec, suppression ou escalade récent.',
                            style: AppTypography.bodyMedium,
                          )
                        else
                          for (final e in sensitive.take(8)) ...[
                            _SensitiveTile(e),
                            const SizedBox(height: 8),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Color _catColor(AuditCategory c) {
    switch (c) {
      case AuditCategory.access:
        return AppColors.statusProgress;
      case AuditCategory.security:
        return AppColors.urgent;
      case AuditCategory.operations:
        return AppColors.champagne;
      case AuditCategory.billing:
        return AppColors.statusConfirmed;
      case AuditCategory.administration:
        return AppColors.statusWaiting;
      case AuditCategory.other:
        return AppColors.grey;
    }
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final int max;
  final String label;
  final bool isToday;
  const _Bar({
    required this.value,
    required this.max,
    required this.label,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            value == 0 ? '' : '$value',
            style: AppTypography.caption.copyWith(fontSize: 9),
          ),
          const SizedBox(height: 2),
          Container(
            height: (ratio * 78) + (value > 0 ? 4 : 0),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(2),
              color: value == 0 ? AppColors.anthracite : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 8.5,
              color: isToday ? AppColors.champagne : AppColors.grey,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _CategoryRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.offWhite,
                ),
              ),
            ),
            Text('$count', style: AppTypography.title.copyWith(fontSize: 14)),
            const SizedBox(width: 8),
            Text('${(ratio * 100).round()}%', style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: AppColors.anthracite,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _SensitiveTile extends StatelessWidget {
  final AuditEntry entry;
  const _SensitiveTile(this.entry);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM · HH:mm', 'fr_BE').format(entry.timestamp);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.urgent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: AppColors.urgent.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.urgent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.offWhite,
                  ),
                ),
                Text(
                  '${entry.actor} · ${entry.target}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Text(date, style: AppTypography.caption),
        ],
      ),
    );
  }
}
