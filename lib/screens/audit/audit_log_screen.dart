import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/audit/audit_export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/crm_agenda.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Journal d'audit — traçabilité des actions sensibles (conformité RGPD).
///
/// Affiche les entrées de [AppState.auditLog] : connexions, changements de
/// mot de passe, escalades sécurité, opérations Peppol, rapprochements, etc.
/// Lecture seule ; permet la recherche, le filtrage et l'export CSV.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final TextEditingController _search = TextEditingController();
  String _roleFilter = '';
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final all = state.auditLog;

    // Rôles présents dans le journal (pour les puces de filtre).
    final roles = <String>{for (final e in all) e.actorRole}.toList()..sort();

    final q = _search.text.trim().toLowerCase();
    final entries = all.where((e) {
      if (_roleFilter.isNotEmpty && e.actorRole != _roleFilter) return false;
      if (q.isEmpty) return true;
      return e.actor.toLowerCase().contains(q) ||
          e.action.toLowerCase().contains(q) ||
          e.target.toLowerCase().contains(q) ||
          (e.detail?.toLowerCase().contains(q) ?? false);
    }).toList();

    final today = DateTime.now();
    final todayCount = all
        .where(
          (e) =>
              e.timestamp.year == today.year &&
              e.timestamp.month == today.month &&
              e.timestamp.day == today.day,
        )
        .length;
    final actorCount = {for (final e in all) e.actor}.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'audit'),
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
          else ...[
            IconButton(
              tooltip: 'Exporter (CSV)',
              icon: const Icon(Icons.table_view_outlined),
              onPressed: all.isEmpty ? null : () => _exportCsv(all),
            ),
            IconButton(
              tooltip: 'Exporter (PDF)',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: all.isEmpty ? null : () => _exportPdf(all),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Traçabilité & confidentialité'),
                      const SizedBox(height: 10),
                      Text('Journal d\'audit', style: AppTypography.headline),
                      const SizedBox(height: 4),
                      Text(
                        'Historique horodaté des actions sensibles. '
                        'Conservé localement, jamais transmis à des tiers.',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: KpiTile(
                              label: 'Entrées',
                              value: '${all.length}',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KpiTile(
                              label: 'Aujourd\'hui',
                              value: '$todayCount',
                              icon: Icons.today_outlined,
                              accent: AppColors.statusProgress,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KpiTile(
                              label: 'Acteurs',
                              value: '$actorCount',
                              icon: Icons.groups_outlined,
                              accent: AppColors.statusConfirmed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Rechercher (acteur, action, cible...)',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _search.clear()),
                                ),
                        ),
                      ),
                      if (roles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              FilterChipLux(
                                label: 'Tous',
                                selected: _roleFilter.isEmpty,
                                count: all.length,
                                onTap: () => setState(() => _roleFilter = ''),
                              ),
                              for (final r in roles) ...[
                                const SizedBox(width: 8),
                                FilterChipLux(
                                  label: r,
                                  selected: _roleFilter == r,
                                  count: all
                                      .where((e) => e.actorRole == r)
                                      .length,
                                  onTap: () => setState(() => _roleFilter = r),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? EmptyState(
                          icon: Icons.history_toggle_off,
                          title: 'Aucune entrée',
                          message: all.isEmpty
                              ? 'Aucune action sensible enregistrée pour le moment.'
                              : 'Aucun résultat pour cette recherche.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _AuditTile(entries[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(List<AuditEntry> entries) async {
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss', 'fr_BE');
    final buf = StringBuffer('Horodatage;Acteur;Rôle;Action;Cible;Détail\n');
    for (final e in entries) {
      String esc(String v) => '"${v.replaceAll('"', '""')}"';
      buf.writeln(
        [
          esc(fmt.format(e.timestamp)),
          esc(e.actor),
          esc(e.actorRole),
          esc(e.action),
          esc(e.target),
          esc(e.detail ?? ''),
        ].join(';'),
      );
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${entries.length} entrées copiées (CSV) dans le presse-papiers.',
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditEntry entry;
  const _AuditTile(this.entry);

  @override
  Widget build(BuildContext context) {
    final initials = entry.actor
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final date = DateFormat(
      'dd/MM/yyyy · HH:mm',
      'fr_BE',
    ).format(entry.timestamp);

    return LuxuryCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(initials: initials.isEmpty ? '?' : initials, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.action,
                        style: AppTypography.title.copyWith(fontSize: 14.5),
                      ),
                    ),
                    Text(date, style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      entry.actor,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      label: entry.actorRole,
                      color: AppColors.champagne,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.target,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.greyLight,
                  ),
                ),
                if (entry.detail != null && entry.detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.detail!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
