import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Guide d'utilisation de GOREX LUXURY CONCIERGE.
///
/// Document d'aide intégré, organisé par profil (membre / équipe) et par
/// domaine fonctionnel. Sert de référence pour la prise en main de
/// l'application sur mobile et sur le web.
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  static const String version = '1.0';
  static const String lastUpdated = '2025';

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  /// Chapitre actif (0 = sommaire).
  int _chapter = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppState>().company;
    final brand = c.brandName.isNotEmpty ? c.brandName : c.legalName;

    final chapters = _chapters(brand);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide d\'utilisation'),
        leading: _chapter > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Sommaire',
                onPressed: () => setState(() => _chapter = 0),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: _chapter == 0
                  ? _sommaire(chapters, brand)
                  : _chapterView(chapters),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sommaire
  // ---------------------------------------------------------------------------

  Widget _sommaire(List<_Chapter> chapters, String brand) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GUIDE D\'UTILISATION', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        Text('Prise en main de $brand', style: AppTypography.displayMedium),
        const SizedBox(height: 6),
        Text(
          'Version ${UserGuideScreen.version} · Dernière mise à jour : '
          '${UserGuideScreen.lastUpdated}',
          style: AppTypography.caption,
        ),
        const SizedBox(height: 10),
        const GoldDivider(width: 60),
        const SizedBox(height: 22),
        Text(
          'Ce guide présente les fonctionnalités de la plateforme et leur '
          'utilisation, pour les membres (clients) comme pour l\'équipe '
          'Gorex. Sélectionnez un chapitre pour le consulter.',
          style: AppTypography.bodyLarge,
        ),
        const SizedBox(height: 22),
        ...chapters.asMap().entries.map((e) {
          final i = e.key;
          final ch = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LuxuryCard(
              onTap: () => setState(() => _chapter = i + 1),
              child: Row(
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
                    child: Icon(ch.icon, size: 17, color: AppColors.champagne),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ch.title,
                          style: AppTypography.title.copyWith(fontSize: 13.5),
                        ),
                        const SizedBox(height: 3),
                        Text(ch.subtitle, style: AppTypography.caption),
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
          );
        }),
        const SizedBox(height: 18),
        const _SignOff(),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Vue chapitre
  // ---------------------------------------------------------------------------

  Widget _chapterView(List<_Chapter> chapters) {
    final ch = chapters[_chapter - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.champagne.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.champagneDark, width: 0.6),
              ),
              child: Icon(ch.icon, size: 18, color: AppColors.champagne),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHAPITRE $_chapter',
                    style: AppTypography.eyebrow.copyWith(fontSize: 9.5),
                  ),
                  const SizedBox(height: 3),
                  Text(ch.title, style: AppTypography.headline),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const GoldDivider(width: 60),
        const SizedBox(height: 18),
        ...ch.blocks,
        const SizedBox(height: 18),
        Row(
          children: [
            if (_chapter > 1)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _chapter -= 1),
                  icon: const Icon(Icons.arrow_back, size: 15),
                  label: const Text('PRÉCÉDENT'),
                ),
              ),
            if (_chapter > 1) const SizedBox(width: 12),
            Expanded(
              child: GoldButton(
                label: _chapter < chapters.length ? 'SUIVANT' : 'SOMMAIRE',
                icon: _chapter < chapters.length
                    ? Icons.arrow_forward
                    : Icons.list,
                fullWidth: true,
                onPressed: () => setState(
                  () => _chapter = _chapter < chapters.length ? _chapter + 1 : 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SignOff(),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Contenu
  // ---------------------------------------------------------------------------

  List<_Chapter> _chapters(String brand) => [
    _Chapter(
      'Prise en main',
      'Accès, connexion et rôles',
      Icons.vpn_key_outlined,
      [
        _p(
          'Bienvenue',
          'Cette application est la plateforme de conciergerie d\'exception de '
              '$brand. Elle permet aux membres de formuler leurs demandes et de '
              'suivre leurs prestations, et à l\'équipe Gorex de les traiter, '
              'facturer et piloter.',
        ),
        _p(
          'Se connecter',
          'Saisissez votre adresse e-mail et votre mot de passe sur l\'écran '
              'd\'accueil, puis validez. À la première connexion, vous pouvez '
              'être invité à remplacer le mot de passe provisoire communiqué '
              'par votre conseiller.',
        ),
        _bullets(
          'Profils et périmètres',
          'Les fonctionnalités affichées dépendent de votre rôle :\n\n'
              '• Membre (client) : demandes, réservations, factures, profil.\n'
              '• Équipe Gorex : demandes, services, itinéraires, réservations, '
              'prestataires, clients, agenda, communication.\n'
              '• Direction (CEO / Manager) : accès complet, y compris finance, '
              'comptabilité, CRM, équipe et gestion des accès.',
        ),
        _p(
          'Navigation',
          'Sur mobile, utilisez le menu (☰) pour parcourir les rubriques. Sur '
              'ordinateur et tablette large, la navigation apparaît sous forme '
              'de barre latérale permanente.',
        ),
      ],
    ),
    _Chapter(
      'Espace membre',
      'Formuler une demande et suivre ses prestations',
      Icons.person_outline,
      [
        _bullets(
          'Accueil',
          'Le tableau de bord membre récapitule vos demandes en cours, vos '
              'prochaines réservations et vos échéances. Utilisez-le comme point '
              'de départ.',
        ),
        _bullets(
          'Formuler une demande',
          'Depuis « Demandes » puis « Nouvelle demande », décrivez votre '
              'besoin : voyage, table, événement, transport, sécurité, '
              'assistance. Précisez dates, lieux et toute contrainte utile. '
              'Votre conseiller prend en charge la demande et vous tient '
              'informé de son avancement.',
        ),
        _bullets(
          'Réservations',
          'La rubrique « Réservations » regroupe les prestations confirmées '
              '(vols, hôtels, tables, voitures avec chauffeur, etc.), avec leurs '
              'détails et statuts.',
        ),
        _bullets(
          'Concierge',
          'La messagerie « Concierge » vous relie directement à votre '
              'interlocuteur Gorex pour toute question ou précision.',
        ),
        _bullets(
          'Factures',
          'Consultez et téléchargez vos factures au format PDF depuis l\'accès '
              'rapide de l\'en-tête ou votre profil. Chaque facture mentionne le '
              'détail de la prestation, la TVA applicable et les coordonnées '
              'officielles de facturation.',
        ),
        _bullets(
          'Profil & préférences',
          'Dans « Profil », mettez à jour vos coordonnées et vos informations de '
              'facturation, et consultez la politique de confidentialité.',
        ),
      ],
    ),
    _Chapter(
      'Demandes & services (équipe)',
      'Traiter les demandes et organiser les prestations',
      Icons.room_service_outlined,
      [
        _bullets(
          'Demandes',
          'La file des demandes présente toutes les requêtes entrantes. Ouvrez '
              'une demande pour la qualifier, l\'assigner à un membre de '
              'l\'équipe, la faire évoluer de statut et échanger avec le membre.',
        ),
        _bullets(
          'Services',
          'Le catalogue des services décrit les prestations proposées et leurs '
              'conditions. Il sert de référence lors du chiffrage.',
        ),
        _bullets(
          'Itinéraires',
          'Construisez des itinéraires sur mesure (étapes, horaires, '
              'prestataires) pour les déplacements et séjours des membres.',
        ),
        _bullets(
          'Réservations',
          'Confirmez, modifiez ou annulez les réservations, et rattachez-les aux '
              'demandes et clients concernés.',
        ),
        _bullets(
          'Prestataires',
          'Gérez votre réseau de partenaires (transport, hôtellerie, '
              'restauration, sécurité) et leurs coordonnées.',
        ),
        _bullets(
          'Agenda',
          'Planifiez et suivez les rendez-vous et échéances de l\'équipe.',
        ),
      ],
    ),
    _Chapter(
      'Finance & facturation',
      'Factures, TVA belge et Peppol',
      Icons.account_balance_outlined,
      [
        _bullets(
          'Finance',
          'La rubrique « Finance » centralise les documents : devis, factures, '
              'notes de crédit. Créez un document, associez-le à un client, et '
              'suivez son statut (brouillon, envoyé, payé, en retard).',
        ),
        _bullets(
          'TVA & conformité belge',
          'L\'application applique automatiquement le régime de TVA :\n\n'
              '• Client particulier (Belgique) : TVA belge au taux applicable.\n'
              '• Client professionnel belge : autoliquidation (reverse charge).\n'
              '• Client professionnel intracommunautaire : exonération '
              '(art. 39bis CTVA).\n'
              '• Client hors UE : hors champ.\n\n'
              'Les numéros d\'entreprise (BCE) et de TVA sont validés '
              '(contrôle modulo-97) et normalisés.',
        ),
        _bullets(
          'Communication structurée (OGM/VCS)',
          'Chaque facture peut être assortie d\'une communication structurée '
              'belge (format +++xxx/xxxx/xxxxx+++, contrôle mod 97) afin de '
              'faciliter le rapprochement des paiements.',
        ),
        _bullets(
          'Peppol',
          'Configurez votre Access Point Peppol dans « Paramètres société » et '
              '« Access Point Peppol ». Les factures destinées aux clients '
              'professionnels belges éligibles peuvent être transmises '
              'électroniquement au format UBL 2.1 (Peppol BIS Billing 3.0 / '
              'EN 16931). Le statut d\'envoi est suivi automatiquement.',
        ),
        _bullets(
          'Export PDF',
          'Générez une facture ou un devis au format PDF, prêt à imprimer ou à '
              'transmettre, avec les coordonnées officielles de l\'émetteur.',
        ),
      ],
    ),
    _Chapter(
      'Comptabilité',
      'Rapprochement bancaire, relances et export',
      Icons.receipt_long_outlined,
      [
        _bullets(
          'Rapprochement bancaire',
          'Importez ou saisissez les mouvements bancaires, puis laissez '
              'l\'application proposer les correspondances avec les factures. '
              'Le rapprochement s\'appuie sur la communication structurée, la '
              'référence, le montant et le nom du contrepartiste. Validez ou '
              'ajustez chaque proposition manuellement si nécessaire.',
        ),
        _bullets(
          'Relances des factures impayées',
          'Les factures échues sont suivies et relancées selon un barème '
              'd\'escalade : 1ʳᵉ relance à 7 jours, 2ᵉ à 21 jours, mise en '
              'demeure à 45 jours. Un e-mail de relance peut être prévisualisé '
              'et envoyé en un clic.',
        ),
        _bullets(
          'Relances automatiques',
          'Dans « Relances automatiques », activez la vérification planifiée : '
              'l\'application contrôle périodiquement les échéances (au '
              'démarrage et/ou selon un intervalle) et prépare les relances '
              'dues. Vous pouvez lancer une exécution immédiate à tout moment.',
        ),
        _bullets(
          'Export comptable',
          'Exportez le journal des ventes au format CSV compatible avec les '
              'logiciels comptables belges (séparateur point-virgule, décimales '
              'à la virgule), filtré par exercice.',
        ),
      ],
    ),
    _Chapter(
      'CRM, équipe & accès',
      'Relation client et gestion du personnel',
      Icons.trending_up_outlined,
      [
        _bullets(
          'CRM',
          'Suivez la relation membre : historique, préférences, valeur, '
              'opportunités et relances commerciales.',
        ),
        _bullets(
          'Équipe',
          'Consultez la composition de l\'équipe, les rôles et les affectations.',
        ),
        _bullets(
          'Accès personnel',
          'Réservé à la direction : créez et gérez les comptes de l\'équipe '
              '(création, activation/désactivation, réinitialisation de mot de '
              'passe, suppression) et attribuez les permissions par rôle.',
        ),
        _bullets(
          'Abonnements',
          'Gérez les niveaux d\'abonnement des membres et leurs avantages.',
        ),
        _bullets(
          'Communication',
          'Centralisez les échanges (messages, notifications) avec les membres '
              'et en interne.',
        ),
      ],
    ),
    _Chapter(
      'Sécurité & confidentialité',
      'Données personnelles et bonnes pratiques',
      Icons.privacy_tip_outlined,
      [
        _bullets(
          'Confidentialité',
          'La discrétion est au cœur de nos engagements. La politique de '
              'confidentialité (RGPD) est accessible depuis l\'application et '
              'depuis la page publique du site.',
        ),
        _bullets(
          'Protection des données',
          'Les données sont traitées conformément au RGPD (UE 2016/679) et à la '
              'loi belge du 30 juillet 2018. Les accès sont contrôlés par rôles '
              'et les transmissions chiffrées.',
        ),
        _bullets(
          'Bonnes pratiques',
          '• Ne partagez jamais vos identifiants.\n'
              '• Verrouillez votre appareil.\n'
              '• Signalez toute activité suspecte à votre conseiller.\n'
              '• Déconnectez-vous sur les appareils partagés.',
        ),
      ],
    ),
    _Chapter(
      'Support',
      'Nous contacter',
      Icons.support_agent_outlined,
      [
        _bullets(
          'Votre conseiller',
          'Pour toute demande, utilisez la messagerie « Concierge » ou la '
              'rubrique « Demandes » : votre interlocuteur dédié vous répond '
              'dans les meilleurs délais.',
        ),
        _bullets(
          'Coordonnées',
          'Les coordonnées officielles de l\'émetteur (adresse, e-mail, '
              'téléphone, numéro d\'entreprise BCE, numéro de TVA, compte '
              'bancaire professionnel) sont disponibles dans « Paramètres '
              'société ». Elles alimentent automatiquement vos documents.',
        ),
        _bullets(
          'Discretion. Access. Excellence.',
          'Notre engagement : la discrétion absolue, l\'accès aux expériences '
              'les plus rares, et l\'excellence du service à chaque instant.',
        ),
      ],
    ),
  ];

  // --- helpers de bloc -------------------------------------------------------

  static _Block _p(String title, String body) =>
      _Block(title: title, body: body);

  static _Block _bullets(String title, String body) =>
      _Block(title: title, body: body);
}

// ---------------------------------------------------------------------------
// Modèles de contenu
// ---------------------------------------------------------------------------

class _Chapter {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_Block> blocks;
  _Chapter(this.title, this.subtitle, this.icon, this.blocks);
}

class _Block extends StatelessWidget {
  final String title;
  final String body;
  const _Block({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.champagne,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headline.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(body, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
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
