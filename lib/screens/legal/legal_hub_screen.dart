import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_sale_screen.dart';
import 'legal_notice_screen.dart';
import 'cookie_policy_screen.dart';

/// Hub « Informations légales » — point d'entrée unique vers l'ensemble des
/// documents juridiques de GOREX LUXURY CONCIERGE.
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppState>().company;
    final brand = c.brandName.isNotEmpty ? c.brandName : c.legalName;

    final docs = <_LegalDoc>[
      _LegalDoc(
        'Politique de confidentialité',
        'Traitement des données personnelles (RGPD), finalités, durées de '
            'conservation et vos droits.',
        Icons.privacy_tip_outlined,
        () => const PrivacyPolicyScreen(),
      ),
      _LegalDoc(
        'Conditions Générales de Vente',
        'Prestations, prix et TVA, paiement, annulation, responsabilité et '
            'règlement des litiges.',
        Icons.description_outlined,
        () => const TermsOfSaleScreen(),
      ),
      _LegalDoc(
        'Mentions légales',
        'Éditeur, hébergeur, propriété intellectuelle, responsabilité et '
            'juridiction compétente.',
        Icons.gavel_outlined,
        () => const LegalNoticeScreen(),
      ),
      _LegalDoc(
        'Politique cookies',
        'Cookies et stockage local utilisés. Aucun traceur publicitaire tiers.',
        Icons.cookie_outlined,
        () => const CookiePolicyScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Informations légales')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INFORMATIONS LÉGALES', style: AppTypography.eyebrow),
                  const SizedBox(height: 10),
                  Text('Transparence et conformité', style: AppTypography.displayMedium),
                  const SizedBox(height: 6),
                  Text('Version 1.0 · Dernière mise à jour : 2025', style: AppTypography.caption),
                  const SizedBox(height: 10),
                  const GoldDivider(width: 60),
                  const SizedBox(height: 22),
                  Text(
                    'Retrouvez ici l\'ensemble des documents juridiques encadrant '
                    'l\'utilisation de $brand et nos prestations. La discrétion et '
                    'la conformité sont au cœur de nos engagements.',
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  ...docs.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LuxuryCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => d.builder()),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.champagne.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: AppColors.champagneDark,
                                  width: 0.6,
                                ),
                              ),
                              child: Icon(d.icon, size: 17, color: AppColors.champagne),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.title,
                                    style: AppTypography.title.copyWith(fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(d.subtitle, style: AppTypography.caption),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.greyDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pour toute question juridique, écrivez à ${c.email}.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 22),
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
}

class _LegalDoc {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;
  _LegalDoc(this.title, this.subtitle, this.icon, this.builder);
}
