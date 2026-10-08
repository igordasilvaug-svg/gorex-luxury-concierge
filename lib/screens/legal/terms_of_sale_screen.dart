import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Conditions Générales de Vente (CGV) de GOREX LUXURY CONCIERGE.
///
/// Conditions applicables aux prestations de conciergerie de luxe fournies par
/// Gorex Group, conformément au droit belge (Code de droit économique, livre VI
/// et livre XII — droit des obligations, et dispositions relatives aux clauses
/// abusives B2C).
class TermsOfSaleScreen extends StatelessWidget {
  const TermsOfSaleScreen({super.key});

  static const String version = '1.0';
  static const String lastUpdated = '2025';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppState>().company;
    final brand = c.brandName.isNotEmpty ? c.brandName : c.legalName;

    return Scaffold(
      appBar: AppBar(title: const Text('Conditions Générales de Vente')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONDITIONS GÉNÉRALES DE VENTE', style: AppTypography.eyebrow),
                  const SizedBox(height: 10),
                  Text(
                    'Prestations de conciergerie',
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
                    'Les présentes Conditions Générales de Vente (« CGV ») '
                    'régissent l\'ensemble des prestations de conciergerie de luxe '
                    'fournies par ${c.legalName} (« $brand ») à ses clients '
                    '(« le Client »). Toute commande implique l\'acceptation sans '
                    'réserve des présentes CGV.',
                    style: AppTypography.bodyLarge,
                  ),
                  _section(
                    '1. Objet et champ d\'application',
                    'Les CGV s\'appliquent aux prestations de conciergerie, '
                        'd\'assistance exécutive, de voyage, de lifestyle et de '
                        'sécurité proposées par $brand. Elles prévalent sur tout '
                        'autre document du Client, sauf dérogation écrite et '
                        'expresse.',
                  ),
                  _section(
                    '2. Devis et formation du contrat',
                    'Toute prestation fait l\'objet d\'un devis précisant sa '
                        'nature, son prix et ses modalités. Le contrat est formé '
                        'par l\'acceptation du devis (signature ou validation '
                        'électronique) et, le cas échéant, par le versement de '
                        'l\'acompte. Les demandes urgentes peuvent être '
                        'confirmées par écrit (courriel) pour garantir la '
                        'traçabilité.',
                  ),
                  _section(
                    '3. Prix et tarification',
                    'Les prix sont exprimés en euros, hors taxes ou toutes taxes '
                        'comprises selon le régime applicable. Le régime de TVA '
                        'est déterminé en fonction de la qualité du Client :\n\n'
                        '• Client particulier (Belgique) : TVA belge au taux '
                        'applicable.\n'
                        '• Client professionnel belge : autoliquidation '
                        '(article 51 §2.4 du Code de la TVA).\n'
                        '• Client professionnel intracommunautaire : exonération '
                        'de TVA (article 39bis du Code de la TVA), sous réserve '
                        'd\'un numéro de TVA intracommunautaire valide.\n'
                        '• Client hors Union européenne : prestation hors champ.\n\n'
                        'Les frais de prestataires tiers (hôtels, transporteurs, '
                        'billetterie) sont refacturés au Client selon les '
                        'conditions convenues.',
                  ),
                  _section(
                    '4. Commande, disponibilité et modification',
                    'Les prestations dépendent de la disponibilité des '
                        'fournisseurs partenaires. $brand s\'efforce de répondre '
                        'aux demandes dans les meilleurs délais, sans garantie de '
                        'disponibilité. Toute modification demandée par le Client '
                        'peut entraîner un ajustement de prix et est soumise à '
                        'l\'acceptation écrite de $brand.',
                  ),
                  _section(
                    '5. Paiement',
                    'Sauf convention contraire, les factures sont payables dans '
                        'un délai de 30 jours à compter de leur date d\'émission, '
                        'par virement sur le compte bancaire professionnel '
                        'indiqué. Les prestations urgentes ou à forte valeur '
                        'peuvent exiger un paiement anticipé. Une communication '
                        'structurée (OGM/VCS) peut être mentionnée sur la facture '
                        'pour faciliter le rapprochement du paiement.\n\n'
                        'Tout retard de paiement entraîne de plein droit, sans '
                        'mise en demeure préalable, des intérêts de retard au '
                        'taux légal belge majoré, ainsi qu\'une indemnité '
                        'forfaitaire pour frais de recouvrement de 40 € '
                        '(article 6.6 du Code de droit économique). Les factures '
                        'impayées font l\'objet de rappels et, le cas échéant, '
                        'd\'une mise en demeure.',
                  ),
                  _section(
                    '6. Facturation électronique (Peppol)',
                    'Pour les Clients professionnels établis en Belgique, la '
                        'facture peut être émise et transmise électroniquement '
                        'via le réseau Peppol, au format UBL 2.1 (Peppol BIS '
                        'Billing 3.0 / norme EN 16931), conformément à la '
                        'réglementation belge sur la facturation électronique.',
                  ),
                  _section(
                    '7. Annulation, report et remboursement',
                    'Les conditions d\'annulation sont précisées par prestation. '
                        'À défaut de conditions spécifiques :\n\n'
                        '• Annulation à plus de 7 jours : remboursement des '
                        'sommes versées, hors frais non récupérables engagés.\n'
                        '• Annulation entre 48 heures et 7 jours : retenue de '
                        '50 % du montant.\n'
                        '• Annulation à moins de 48 heures ou « no-show » : '
                        'montant dû en totalité.\n\n'
                        'Les frais engagés auprès de prestataires tiers non '
                        'remboursables restent dus par le Client.',
                  ),
                  _section(
                    '8. Obligations du Client',
                    'Le Client s\'engage à fournir des informations exactes et '
                        'complètes, à coopérer loyalement, à respecter les '
                        'conditions des prestataires partenaires, et à régler les '
                        'sommes dues. Le Client est responsable des documents de '
                        'voyage (passeport, visa, assurance) le concernant et les '
                        'personnes qu\'il représente.',
                  ),
                  _section(
                    '9. Responsabilité de $brand',
                    '$brand est tenue à une obligation de moyens. Sa '
                        'responsabilité ne saurait être engagée en cas de force '
                        'majeure, de fait d\'un tiers prestataire, de mauvaise '
                        'information fournie par le Client, ou d\'événement '
                        'indépendant de sa volonté (grèves, conditions '
                        'météorologiques, décisions administratives). En tout '
                        'état de cause, la responsabilité de $brand est limitée '
                        'au montant des sommes effectivement payées par le Client '
                        'pour la prestation concernée, sans préjudice des règles '
                        'impératives applicables aux consommateurs.',
                  ),
                  _section(
                    '10. Confidentialité',
                    'La discrétion est au cœur des engagements de $brand. Les '
                        'informations relatives au Client et aux prestations sont '
                        'traitées de manière strictement confidentielle, dans les '
                        'limites de la Politique de confidentialité et des '
                        'obligations légales.',
                  ),
                  _section(
                    '11. Protection des données personnelles',
                    'Le traitement des données à caractère personnel est décrit '
                        'dans la Politique de confidentialité, conforme au RGPD '
                        '(UE 2016/679) et à la loi belge du 30 juillet 2018. Le '
                        'Client dispose notamment des droits d\'accès, de '
                        'rectification et d\'effacement, exerçables à l\'adresse '
                        '${c.email}.',
                  ),
                  _section(
                    '12. Force majeure',
                    'Aucune partie ne sera tenue responsable d\'un manquement '
                        'résultant d\'un événement de force majeure au sens du '
                        'droit belge. La partie affectée en informe l\'autre dans '
                        'les meilleurs délais.',
                  ),
                  _section(
                    '13. Droit applicable et règlement des litiges',
                    'Les CGV sont soumises au droit belge. En cas de litige, les '
                        'parties s\'efforceront de trouver une solution amiable. '
                        'À défaut, les tribunaux de l\'arrondissement du siège '
                        'social de ${c.legalName} sont compétents, sous réserve '
                        'des règles impératives protégeant les consommateurs.\n\n'
                        'Client consommateur : vous pouvez également recourir au '
                        'Service de Médiation pour le Consommateur (boulevard du '
                        'Roi Albert II 8, 1000 Bruxelles) ou à la plateforme '
                        'européenne de règlement en ligne des litiges (RLL).',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En validant une commande auprès de $brand, le Client '
                    'déclare avoir lu et accepté les présentes CGV.',
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
