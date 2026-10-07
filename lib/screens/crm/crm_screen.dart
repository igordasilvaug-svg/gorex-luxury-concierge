import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  ProspectStage? _filter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    var list = [...s.prospects];
    if (_filter != null) list = list.where((p) => p.stage == _filter).toList();

    final totalValue = s.prospects
        .where((p) => p.stage != ProspectStage.lost)
        .fold(0.0, (sum, p) => sum + p.estimatedValue);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CRM VIP', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Text(
              'Prospects · communications · relances · contrats · valeur client',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 780 ? 3 : 1;
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                final kpis = [
                  KpiTile(
                    label: 'Prospects actifs',
                    value: '${s.prospects.length}',
                    icon: Icons.trending_up_outlined,
                  ),
                  KpiTile(
                    label: 'Valeur pipeline',
                    value: eur.format(totalValue),
                    icon: Icons.payments_outlined,
                    accent: AppColors.champagne,
                  ),
                  KpiTile(
                    label: 'Clients convertis',
                    value: '${s.clients.length}',
                    icon: Icons.verified_outlined,
                    accent: AppColors.statusConfirmed,
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
            SectionHeader(title: 'Pipeline', subtitle: 'Par étape'),
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
                  ...ProspectStage.values.map(
                    (st) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChipLux(
                        label: st.label,
                        selected: _filter == st,
                        onTap: () =>
                            setState(() => _filter = _filter == st ? null : st),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...list.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProspectCard(prospect: p),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ProspectCard extends StatelessWidget {
  final dynamic prospect;
  const _ProspectCard({required this.prospect});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: _initials(prospect.name), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prospect.name, style: AppTypography.title),
                    if (prospect.company != null)
                      Text(prospect.company!, style: AppTypography.caption),
                  ],
                ),
              ),
              StatusPill(
                label: prospect.stage.label,
                color: prospect.stage.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.mail_outline, prospect.email),
              _meta(Icons.phone_outlined, prospect.phone),
              _meta(Icons.category_outlined, prospect.category.label),
              if (prospect.ownerName != null)
                _meta(Icons.person_outline, prospect.ownerName!),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valeur estimée',
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                    Text(
                      eur.format(prospect.estimatedValue),
                      style: AppTypography.title.copyWith(
                        fontSize: 15,
                        color: AppColors.champagne,
                      ),
                    ),
                  ],
                ),
              ),
              if (prospect.nextFollowUp != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relance',
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy',
                        'fr_BE',
                      ).format(prospect.nextFollowUp!),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (prospect.communicationLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'HISTORIQUE',
              style: AppTypography.label.copyWith(fontSize: 9.5),
            ),
            const SizedBox(height: 6),
            ...prospect.communicationLog.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 5,
                      color: AppColors.champagne,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c, style: AppTypography.caption)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _changeStage(context, s),
              icon: const Icon(Icons.swap_horiz, size: 15),
              label: const Text('ÉTAPE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.grey),
      const SizedBox(width: 5),
      Text(t, style: AppTypography.caption.copyWith(fontSize: 10.5)),
    ],
  );

  void _changeStage(BuildContext context, AppState s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: SectionHeader(title: 'Changer l\'étape du pipeline'),
            ),
            const Divider(height: 1),
            ...ProspectStage.values.map(
              (st) => ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: st.color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  st.label,
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
                trailing: prospect.stage == st
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.champagne,
                      )
                    : null,
                onTap: () {
                  s.updateProspect(prospect.copyWith(stage: st));
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
