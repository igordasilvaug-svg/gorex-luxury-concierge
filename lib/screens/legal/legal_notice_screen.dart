import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Mentions légales de GOREX LUXURY CONCIERGE.
///
/// Informations d'identification de l'éditeur, de l'hébergeur et
/// responsabilités, conformément aux obligations belges (loi du 11 mars 2003
/// sur certains aspects juridiques des services de la société de
/// l'information et Code de droit économique, livre VI).
class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  static const String version = '1.0';
  static const String lastUpdated = '2025';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppState>().company;
    final brand = c.brandName.isNotEmpty ? c.brandName : c.legalName;

    return Scaffold(
      appBar: AppBar(title: const Text('Mentions légales')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MENTIONS LÉGALES', style: AppTypography.eyebrow),
                  const SizedBox(height: 10),
                  Text(
                    'Informations légales',
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
                  _intro(brand, c.legalName),
                  _section(
                    '1. Éditeur du site et de l\'application',
                    '${c.legalName}\n'
                        '${c.addressLine}, ${c.postalCode} ${c.city}, ${c.country}\n'
                        'Numéro d\'entreprise (BCE) : ${c.companyNumber}\n'
                        'Numéro de TVA : ${c.vatNumber}\n'
                        'E-mail : ${c.email}\n'
                        'Téléphone : ${c.phone}\n'
                        'Site web : ${c.website}',
                  ),
                  _section(
                    '2. Forme juridique et capital',
                    'La société ${c.legalName} est constituée sous forme de '
                        'société anonyme (SA) de droit belge. Les informations '
                        'relatives à la forme juridique, au capital social et '
                        'aux dirigeants sont tenues à jour auprès de la Banque-'
                        'Carrefour des Entreprises (BCE) et publiées au Moniteur '
                        'belge.',
                  ),
                  _section(
                    '3. Responsable de la publication',
                    'Le responsable de la publication est la direction de '
                        '${c.legalName}, joignable à l\'adresse ${c.email}.',
                  ),
                  _section(
                    '4. Hébergement',
                    'L\'application web est hébergée sur l\'infrastructure '
                        'Cloudflare (Cloudflare, Inc., 101 Townsend St, San '
                        'Francisco, CA 94107, États-Unis), au moyen d\'un réseau '
                        'de diffusion mondial. Les données applicatives sont '
                        'stockées sur l\'appareil de l\'utilisateur (stockage '
                        'local sécurisé).',
                  ),
                  _section(
                    '5. Propriété intellectuelle',
                    'L\'ensemble des éléments de l\'application et du site '
                        '(marques, logos, textes, graphismes, interfaces, base '
                        'de données) est la propriété exclusive de ${c.legalName} '
                        'ou de ses partenaires. Toute reproduction, '
                        'représentation ou exploitation, totale ou partielle, '
                        'sans autorisation écrite préalable est interdite et '
                        'constitue une contrefaçon sanctionnée par le Code de '
                        'droit économique (livre XI).',
                  ),
                  _section(
                    '6. Responsabilité',
                    '${c.legalName} s\'efforce d\'assurer l\'exactitude et la '
                        'mise à jour des informations diffusées, sans pouvoir '
                        'garantir l\'absence d\'erreur. La responsabilité de '
                        '${c.legalName} ne saurait être engagée en cas de dommage '
                        'résultant de l\'utilisation de l\'application ou de '
                        'l\'impossibilité temporaire d\'y accéder. Les liens '
                        'hypertextes vers des sites tiers n\'engagent pas la '
                        'responsabilité de ${c.legalName} quant à leur contenu.',
                  ),
                  _section(
                    '7. Données personnelles et cookies',
                    'Le traitement des données à caractère personnel et '
                        'l\'usage des cookies sont décrits respectivement dans la '
                        'Politique de confidentialité et la Politique cookies, '
                        'accessibles depuis l\'application.',
                  ),
                  _section(
                    '8. Droit applicable et juridiction',
                    'Les présentes mentions légales sont soumises au droit '
                        'belge. Tout litige relatif à leur interprétation ou à '
                        'leur exécution relève de la compétence exclusive des '
                        'tribunaux de l\'arrondissement du siège social de '
                        '${c.legalName}, sous réserve des règles impératives de '
                        'compétence.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En utilisant $brand, vous reconnaissez avoir pris '
                    'connaissance des présentes mentions légales.',
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

  Widget _intro(String brand, String legalName) => Text(
    '$brand est édité par $legalName. Les '
    'présentes mentions légales ont pour objet d\'identifier l\'éditeur de '
    'l\'application et du site, et de préciser les conditions juridiques '
    'd\'utilisation du service.',
    style: AppTypography.bodyLarge,
  );

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
