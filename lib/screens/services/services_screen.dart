import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/service_catalog.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../requests/new_request_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catalogue de services', style: AppTypography.displayMedium),
            const SizedBox(height: 6),
            Text(
              'Luxury Concierge · Executive Assistance · Travel · Lifestyle · Security',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),
            ...ServiceDomain.values.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _domainCard(context, s, d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _domainCard(BuildContext context, AppState s, ServiceDomain d) {
    final count = s.requests.where((r) => r.domain == d).length;
    final isSecurity = d == ServiceDomain.security;
    final isMedical = d == ServiceDomain.medical;
    return LuxuryCard(
      highlighted: isSecurity,
      borderColor: isSecurity ? AppColors.champagneDark : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.champagne.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.champagneDark,
                    width: 0.6,
                  ),
                ),
                child: Icon(d.icon, size: 20, color: AppColors.champagne),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          d.label,
                          style: AppTypography.headline.copyWith(fontSize: 17),
                        ),
                        if (isSecurity) ...[
                          const SizedBox(width: 8),
                          const StatusPill(
                            label: 'GOREX SECURITY',
                            color: AppColors.champagne,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ServiceCatalog.domainDescription(d),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (count > 0)
                StatusPill(
                  label: '$count demandes',
                  color: AppColors.greyLight,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ServiceCatalog.forDomain(d).map((sub) {
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewRequestScreen(urgentMode: false),
                  ),
                ),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.anthracite,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.divider, width: 0.6),
                  ),
                  child: Text(
                    sub,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.greyLight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (isMedical) ...[
            const SizedBox(height: 12),
            Text(
              'Note : les prestations médicales sont réalisées par des prestataires externes agréés. Gorex assure la coordination.',
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
