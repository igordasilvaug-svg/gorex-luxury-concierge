import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/subscription_tier.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tiers = [...s.tiers]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
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
            Text('Abonnements', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Text(
              'Formules configurables · prix, avantages, priorité, SLA — non figés',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),
            Text(
              'Tous les paramètres sont modifiables par l\'administrateur. Les prix ne sont jamais codés en dur.',
              style: AppTypography.caption.copyWith(color: AppColors.grey),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 760 ? 2 : 1);
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: tiers
                      .map(
                        (t) => SizedBox(
                          width: w,
                          child: _TierCard(tier: t, eur: eur),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final SubscriptionTier tier;
  final NumberFormat eur;
  const _TierCard({required this.tier, required this.eur});

  @override
  Widget build(BuildContext context) {
    final isTop = tier.displayOrder == 4;
    return LuxuryCard(
      highlighted: isTop,
      borderColor: isTop ? AppColors.champagneDark : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.name,
                  style: AppTypography.title.copyWith(
                    color: AppColors.champagne,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
              if (tier.conciergeDedicated)
                const StatusPill(label: 'Dédié', color: AppColors.champagne),
            ],
          ),
          const SizedBox(height: 8),
          Text(tier.tagline, style: AppTypography.caption),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                eur.format(tier.annualPrice),
                style: AppTypography.numberLarge.copyWith(fontSize: 28),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('/ an', style: AppTypography.caption),
              ),
            ],
          ),
          Text(
            '${eur.format(tier.monthlyPrice)} / mois',
            style: AppTypography.caption,
          ),
          const Divider(height: 24),
          _line(Icons.inbox_outlined, 'Demandes : ${tier.requestsLabel}'),
          _line(Icons.priority_high, 'Priorité : ${tier.priority}'),
          _line(
            Icons.schedule_outlined,
            'SLA : réponse < ${tier.responseMinutes} min',
          ),
          _line(Icons.access_time, 'Disponibilité : ${tier.availability}'),
          if (tier.includedServices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('INCLUS', style: AppTypography.label.copyWith(fontSize: 9.5)),
            const SizedBox(height: 6),
            ...tier.includedServices.map(
              (e) => _bullet(e, AppColors.statusConfirmed),
            ),
          ],
          if (tier.excludedServices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'FACTURÉ SÉPARÉMENT',
              style: AppTypography.label.copyWith(fontSize: 9.5),
            ),
            const SizedBox(height: 6),
            ...tier.excludedServices.map((e) => _bullet(e, AppColors.grey)),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('CONFIGURER'),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 13, color: AppColors.champagne),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(fontSize: 12.5),
          ),
        ),
      ],
    ),
  );

  Widget _bullet(String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, right: 8),
          child: Icon(Icons.circle, size: 5, color: color),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    ),
  );

  void _edit(BuildContext context) {
    final annual = TextEditingController(
      text: tier.annualPrice.toStringAsFixed(0),
    );
    final monthly = TextEditingController(
      text: tier.monthlyPrice.toStringAsFixed(0),
    );
    final requests = TextEditingController(
      text: tier.requestsIncluded < 0 ? '-1' : tier.requestsIncluded.toString(),
    );
    final priority = TextEditingController(text: tier.priority);
    final sla = TextEditingController(text: tier.responseMinutes.toString());
    final included = TextEditingController(
      text: tier.includedServices.join(', '),
    );
    final excluded = TextEditingController(
      text: tier.excludedServices.join(', '),
    );

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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Configurer ${tier.name}', style: AppTypography.headline),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field('PRIX ANNUEL (€)', annual)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('PRIX MENSUEL (€)', monthly)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field('DEMANDES / MOIS (-1 = illimité)', requests),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _field('SLA (min)', sla)),
                ],
              ),
              const SizedBox(height: 12),
              _field('PRIORITÉ', priority),
              const SizedBox(height: 12),
              _field('SERVICES INCLUS (séparés par ,)', included),
              const SizedBox(height: 12),
              _field('SERVICES FACTURÉS SÉPARÉMENT', excluded),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Enregistrer',
                fullWidth: true,
                onPressed: () {
                  final s = ctx.read<AppState>();
                  s.updateTier(
                    tier.copyWith(
                      annualPrice:
                          double.tryParse(annual.text) ?? tier.annualPrice,
                      monthlyPrice:
                          double.tryParse(monthly.text) ?? tier.monthlyPrice,
                      requestsIncluded:
                          int.tryParse(requests.text) ?? tier.requestsIncluded,
                      priority: priority.text.trim(),
                      responseMinutes:
                          int.tryParse(sla.text) ?? tier.responseMinutes,
                      includedServices: included.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      excludedServices: excluded.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    ),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Formule mise à jour.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: AppTypography.label.copyWith(fontSize: 9.5)),
      ),
      TextField(
        controller: c,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
      ),
    ],
  );
}
