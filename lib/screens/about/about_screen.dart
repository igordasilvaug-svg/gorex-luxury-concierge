import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/language_selector.dart';
import '../legal/legal_hub_screen.dart';

/// Page « À propos » de GOREX LUXURY CONCIERGE.
///
/// Présente la maison, ses cinq piliers et ses engagements. Entièrement
/// localisée (FR / NL / EN) via `AppState.tr`.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.company;
    final brand = c.brandName.isNotEmpty ? c.brandName : c.legalName;

    final pillars = <_Pillar>[
      _Pillar(Icons.room_service_outlined, s.tr('about.pillar.concierge')),
      _Pillar(Icons.work_outline, s.tr('about.pillar.executive')),
      _Pillar(Icons.flight_takeoff_outlined, s.tr('about.pillar.travel')),
      _Pillar(Icons.local_activity_outlined, s.tr('about.pillar.lifestyle')),
      _Pillar(Icons.shield_outlined, s.tr('about.pillar.security')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('nav.about')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(child: LanguageSelector(dense: true)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tr('about.eyebrow'), style: AppTypography.eyebrow),
                  const SizedBox(height: 10),
                  Text(s.tr('about.title'), style: AppTypography.displayMedium),
                  const SizedBox(height: 6),
                  Text(
                    '$brand · ${s.tr('about.version')} $version',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 10),
                  const GoldDivider(width: 60),
                  const SizedBox(height: 22),
                  const Center(child: GorexBrand()),
                  const SizedBox(height: 24),
                  Text(s.tr('about.intro'), style: AppTypography.bodyLarge),
                  const SizedBox(height: 26),

                  // Les cinq piliers
                  SectionHeader(title: s.tr('about.pillars_title')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: pillars
                        .map(
                          (p) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.cardGradient,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.divider,
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.icon,
                                  size: 16,
                                  color: AppColors.champagne,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  p.label,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 28),

                  // Nos engagements
                  SectionHeader(title: s.tr('about.values_title')),
                  const SizedBox(height: 12),
                  _valueCard(
                    Icons.visibility_off_outlined,
                    s.tr('about.value.discretion'),
                    s.tr('about.value.discretion_body'),
                  ),
                  _valueCard(
                    Icons.vpn_key_outlined,
                    s.tr('about.value.access'),
                    s.tr('about.value.access_body'),
                  ),
                  _valueCard(
                    Icons.workspace_premium_outlined,
                    s.tr('about.value.excellence'),
                    s.tr('about.value.excellence_body'),
                  ),
                  const SizedBox(height: 18),

                  // Contact
                  SectionHeader(title: s.tr('about.contact_title')),
                  const SizedBox(height: 12),
                  LuxuryCard(
                    child: Column(
                      children: [
                        InfoRow(label: 'E-mail', value: c.email),
                        const Divider(height: 1),
                        InfoRow(label: 'Téléphone', value: c.phone),
                        const Divider(height: 1),
                        InfoRow(label: 'Site web', value: c.website),
                        const Divider(height: 1),
                        InfoRow(
                          label: 'Adresse',
                          value:
                              '${c.addressLine}, ${c.postalCode} ${c.city}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Informations légales
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalHubScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.gavel_outlined, size: 15),
                      label: Text(
                        s.tr('about.legal_title').toUpperCase(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'DISCRETION. ACCESS. EXCELLENCE.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                        color: AppColors.greyDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _valueCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LuxuryCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.champagne.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: AppColors.champagneDark,
                  width: 0.6,
                ),
              ),
              child: Icon(icon, size: 16, color: AppColors.champagne),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pillar {
  final IconData icon;
  final String label;
  const _Pillar(this.icon, this.label);
}
