import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Politique cookies de GOREX LUXURY CONCIERGE.
///
/// Informe l'utilisateur sur l'usage du stockage local et des cookies,
/// conformément au RGPD et à la directive ePrivacy (2002/58/CE), ainsi qu'aux
/// lignes directrices de l'Autorité de protection des données belge.
class CookiePolicyScreen extends StatelessWidget {
  const CookiePolicyScreen({super.key});

  static const String version = '1.0';
  static const String lastUpdated = '2025';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppState>().company;
    final brand = c.brandName.isNotEmpty ? c.brandName : c.legalName;

    return Scaffold(
      appBar: AppBar(title: const Text('Politique cookies')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('POLITIQUE COOKIES', style: AppTypography.eyebrow),
                  const SizedBox(height: 10),
                  Text(
                    'Cookies et stockage local',
                    style: AppTypography.displayMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Version $version · Dernière mise à jour : $lastUpdated',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 10),
                  const GoldDivider(width: 60),
                  const SizedBox(height: 22),
                  Text(
                    'La présente politique explique comment $brand utilise les '
                    'cookies et les technologies de stockage local, et comment '
                    'vous pouvez les contrôler. Elle complète la Politique de '
                    'confidentialité.',
                    style: AppTypography.bodyLarge,
                  ),
                  _section(
                    '1. Qu\'est-ce qu\'un cookie ?',
                    'Un cookie est un petit fichier texte déposé sur votre '
                        'appareil lors de la consultation d\'un site. Les '
                        'applications mobiles et web utilisent également un '
                        'stockage local équivalent (localStorage, shared '
                        'preferences). Ces technologies permettent de faire '
                        'fonctionner le service et de mémoriser vos préférences.',
                  ),
                  _section(
                    '2. Cookies et stockages utilisés',
                    '$brand applique une approche minimaliste, au service de la '
                        'discrétion. Les éléments suivants sont utilisés :\n\n'
                        '• Session et authentification — stockage local, '
                        'nécessaire au fonctionnement.\n'
                        '• Préférences d\'affichage (langue, thème) — stockage '
                        'local, nécessaire.\n'
                        '• Données applicatives (cache de vos informations) — '
                        'stockage local, nécessaire.\n'
                        '• Mesure d\'audience — non utilisée.\n'
                        '• Publicité et traceurs tiers — non utilisés.',
                  ),
                  _section(
                    '3. Cookies strictement nécessaires',
                    'Ces éléments sont indispensables au fonctionnement de '
                        'l\'application (session, sécurité, préférences). Ils ne '
                        'requièrent pas de consentement préalable, conformément à '
                        'la réglementation. Leur désactivation empêcherait '
                        'l\'utilisation normale du service.',
                  ),
                  _section(
                    '4. Absence de cookies publicitaires et de traçage',
                    '$brand ne dépose aucun cookie publicitaire ni traceur tiers '
                        'de suivi comportemental. Aucune donnée n\'est revendue '
                        'à des fins marketing. Le moteur de rendu de l\'application '
                        'web (CanvasKit) est chargé depuis un réseau de diffusion '
                        'de confiance ; aucun profil publicitaire n\'est '
                        'constitué.',
                  ),
                  _section(
                    '5. Consentement et gestion',
                    'Les cookies strictement nécessaires étant seuls utilisés, '
                        'aucun bandeau de consentement n\'est requis. Vous pouvez '
                        'à tout moment supprimer le stockage local via les '
                        'réglages de votre navigateur ou de votre appareil, ou en '
                        'effaçant les données de l\'application. Cette action '
                        'réinitialise votre session.',
                  ),
                  _section(
                    '6. Durée de conservation',
                    'Le stockage de session est effacé à la déconnexion ou à la '
                        'fermeture du navigateur selon le cas. Les préférences '
                        'sont conservées jusqu\'à leur suppression manuelle. Les '
                        'données de compte suivent les durées décrites dans la '
                        'Politique de confidentialité.',
                  ),
                  _section(
                    '7. Vos droits',
                    'Conformément au RGPD, vous disposez d\'un droit d\'accès, '
                        'de rectification, d\'effacement et d\'opposition sur vos '
                        'données. Pour toute question relative aux cookies, '
                        'écrivez à ${c.email}.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En poursuivant l\'utilisation de $brand, vous reconnaissez '
                    'avoir pris connaissance de la présente politique cookies.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const _SignOff(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headline.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        Text(body, style: AppTypography.bodyMedium),
      ],
    ),
  );
}

class _SignOff extends StatelessWidget {
  const _SignOff();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'DISCRETION. ACCESS. EXCELLENCE.',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 4,
        color: AppColors.greyDark,
      ),
    ),
  );
}
