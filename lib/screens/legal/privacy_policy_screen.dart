import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Politique de confidentialité de GOREX LUXURY CONCIERGE.
///
/// Conforme au Règlement général sur la protection des données (RGPD /
/// AVG — UE 2016/679) et à la loi belge du 30 juillet 2018 relative à la
/// protection des personnes physiques à l'égard des traitements de données
/// à caractère personnel.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// Version du document — à incrémenter lors de toute modification.
  static const String version = '1.0';
  static const String lastUpdated = '2025';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.company;

    return Scaffold(
      appBar: AppBar(title: const Text('Politique de confidentialité')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POLITIQUE DE CONFIDENTIALITÉ',
                    style: AppTypography.eyebrow,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Protection des données personnelles',
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
                  _intro(c.brandName.isNotEmpty ? c.brandName : c.legalName),
                  const SizedBox(height: 8),
                  _section(
                    '1. Responsable du traitement',
                    'Le responsable du traitement des données à caractère '
                        'personnel collectées via l\'application '
                        '${c.brandName.isNotEmpty ? c.brandName : c.legalName} '
                        'est :\n\n'
                        '${c.legalName}\n'
                        '${c.addressLine}, ${c.postalCode} ${c.city}, ${c.country}\n'
                        'Numéro d\'entreprise (BCE) : ${c.companyNumber}\n'
                        'Numéro de TVA : ${c.vatNumber}\n'
                        'E-mail : ${c.email}\n'
                        'Téléphone : ${c.phone}',
                  ),
                  _section(
                    '2. Données collectées',
                    'Dans le cadre de la fourniture de ses services de '
                        'conciergerie de luxe, ${c.legalName} traite les '
                        'catégories de données suivantes :\n\n'
                        '• Identité et coordonnées : nom, prénom, adresse, '
                        'e-mail, téléphone, nationalité.\n'
                        '• Données professionnelles : raison sociale, numéro '
                        'd\'entreprise (BCE), numéro de TVA, adresse de '
                        'facturation.\n'
                        '• Données de service : demandes, réservations, '
                        'itinéraires, préférences de voyage, préférences '
                        'alimentaires, centres d\'intérêt.\n'
                        '• Données financières : factures, devis, paiements, '
                        'coordonnées bancaires.\n'
                        '• Données de connexion : identifiant, horodatage des '
                        'accès, journal d\'activité.\n'
                        '• Données sensibles éventuelles (santé, sécurité) : '
                        'uniquement lorsque la prestation l\'exige, avec '
                        'consentement explicite.',
                  ),
                  _section(
                    '3. Finalités et bases légales',
                    'Les données sont traitées pour les finalités suivantes, '
                        'chacune reposant sur une base légale (art. 6 RGPD) :\n\n'
                        '• Exécution du contrat de conciergerie — exécution '
                        'd\'un contrat.\n'
                        '• Gestion des réservations, itinéraires et demandes — '
                        'exécution d\'un contrat.\n'
                        '• Facturation et obligations comptables — obligation '
                        'légale (droit comptable belge).\n'
                        '• Facturation électronique via le réseau Peppol — '
                        'obligation légale.\n'
                        '• Sécurité, prévention de la fraude et gestion des '
                        'accès — intérêt légitime.\n'
                        '• Communications marketing et offres personnalisées — '
                        'consentement (révocable à tout moment).',
                  ),
                  _section(
                    '4. Destinataires et sous-traitants',
                    'Les données peuvent être communiquées, dans la stricte '
                        'mesure du nécessaire, à :\n\n'
                        '• Notre personnel habilité (concierges, gestionnaires, '
                        'équipe financière) soumis à une obligation de '
                        'confidentialité.\n'
                        '• Nos prestataires partenaires (hôtels, transporteurs, '
                        'sécurité, coordination médicale) pour l\'exécution de '
                        'la prestation.\n'
                        '• Nos sous-traitants techniques (hébergement, '
                        'facturation électronique Peppol, prestataire de '
                        'paiement).\n'
                        '• Les autorités administratives ou judiciaires '
                        'lorsqu\'une obligation légale l\'impose.\n\n'
                        'Tout sous-traitant agit sur instruction documentée et '
                        'présente des garanties conformes à l\'article 28 RGPD.',
                  ),
                  _section(
                    '5. Transferts hors de l\'Union européenne',
                    'Les données sont en principe hébergées au sein de l\'Espace '
                        'économique européen (EEE). Tout transfert vers un pays '
                        'tiers est encadré par des garanties appropriées '
                        '(clauses contractuelles types de la Commission '
                        'européenne, décision d\'adéquation), conformément au '
                        'chapitre V du RGPD.',
                  ),
                  _section(
                    '6. Durée de conservation',
                    'Les données sont conservées le temps nécessaire aux '
                        'finalités décrites :\n\n'
                        '• Données de compte : pendant la relation contractuelle, '
                        'puis 5 ans à compter de sa fin.\n'
                        '• Documents comptables et factures : 7 ans '
                        '(obligation légale belge).\n'
                        '• Journaux de connexion : 12 mois maximum.\n'
                        '• Données marketing : jusqu\'au retrait du consentement.',
                  ),
                  _section(
                    '7. Vos droits',
                    'Conformément aux articles 15 à 22 du RGPD, vous disposez '
                        'des droits suivants :\n\n'
                        '• Droit d\'accès à vos données.\n'
                        '• Droit de rectification des données inexactes.\n'
                        '• Droit à l\'effacement (« droit à l\'oubli »).\n'
                        '• Droit à la limitation du traitement.\n'
                        '• Droit d\'opposition au traitement.\n'
                        '• Droit à la portabilité des données.\n'
                        '• Droit de retirer votre consentement à tout moment.\n\n'
                        'Pour exercer ces droits, écrivez à ${c.email}. Une '
                        'réponse vous sera adressée dans un délai d\'un mois.',
                  ),
                  _section(
                    '8. Sécurité',
                    'GOREX LUXURY CONCIERGE met en œuvre des mesures techniques '
                        'et organisationnelles appropriées : chiffrement des '
                        'transmissions, contrôle d\'accès par rôles, journal '
                        'd\'audit, sauvegardes régulières et politique de '
                        'confidentialité interne. En cas de violation de '
                        'données susceptible d\'engendrer un risque élevé, '
                        'l\'Autorité de protection des données et les personnes '
                        'concernées sont notifiées conformément aux articles 33 '
                        'et 34 du RGPD.',
                  ),
                  _section(
                    '9. Autorité de contrôle',
                    'Vous avez le droit d\'introduire une réclamation auprès de '
                        'l\'Autorité de protection des données (APD) :\n\n'
                        'Autorité de protection des données (APD/Gegevensbescher'
                        'mingsautoriteit)\n'
                        'Rue de la Presse 35, 1000 Bruxelles, Belgique\n'
                        'contact@apd-gba.be — www.autoriteprotectiondonnees.be',
                  ),
                  _section(
                    '10. Cookies et stockage local',
                    'L\'application utilise un stockage local (shared '
                        'preferences) pour la session et vos préférences. Ces '
                        'données restent sur votre appareil et ne sont pas '
                        'utilisées à des fins publicitaires. Aucun cookie tiers '
                        'de suivi publicitaire n\'est déposé.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En utilisant ${c.brandName.isNotEmpty ? c.brandName : c.legalName}, '
                    'vous reconnaissez avoir pris connaissance de la présente '
                    'politique de confidentialité.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 24),
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

  Widget _intro(String brand) => Text(
    '$brand accorde une importance primordiale à la protection de la vie '
    'privée et à la confidentialité de ses membres. La présente politique '
    'décrit la manière dont vos données à caractère personnel sont collectées, '
    'utilisées, conservées et protégées.',
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
