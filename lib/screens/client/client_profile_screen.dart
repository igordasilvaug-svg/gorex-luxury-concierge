import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billing/subscription_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../documents/document_service.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/user_guide_screen.dart';
import '../legal/legal_hub_screen.dart';
import '../about/about_screen.dart';
import '../access/change_password_dialog.dart';
import '../account/my_account_edit_screen.dart';
import '../../widgets/language_selector.dart';
import 'client_subscription_screen.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final concierge = s.userById(client?.assignedConciergeId);
    // Abonnement RÉEL du client (null = aucun contrat). Remplace l'ancien
    // `tierById(...)`, qui affichait le palier attribué d'office comme s'il
    // s'agissait d'un abonnement souscrit.
    final sub = s.mySubscription;

    if (client == null) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Profil indisponible',
        message: 'Aucun profil client associé.',
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(initials: _initials(client.fullName), size: 58),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.fullName, style: AppTypography.headline),
                      const SizedBox(height: 3),
                      Text(
                        '${client.code} · ${client.category.label}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // ── CE QUI ÉTAIT FAUX ────────────────────────────────────
                // On affichait ici le palier du client (`tier.name`) quelle
                // que soit sa situation. Tout nouvel inscrit recevait donc la
                // mention « GOREX ESSENTIAL » comme s'il était abonné, alors
                // qu'il n'avait rien demandé, rien signé et rien payé. Un
                // palier attribué par défaut n'est PAS un abonnement.
                //
                // Désormais : seule une demande ou un contrat réel donne lieu
                // à une pastille de formule. Sinon, on affiche l'état vrai.
                if (sub != null)
                  StatusPill(
                    label: sub.tierName,
                    color: sub.isBillable
                        ? AppColors.champagne
                        : AppColors.greyLight,
                  )
                else
                  const StatusPill(
                    label: 'Aucun abonnement',
                    color: AppColors.grey,
                  ),
                const SizedBox(width: 8),
                ConfidentialityBadge(level: client.confidentiality),
              ],
            ),
            const SizedBox(height: 20),

            // ── Fiche du contrat réel ────────────────────────────────────
            // L'ancien bloc annonçait « Contrat annuel : 96 000 € » au titre
            // du palier, sans qu'aucun contrat n'existe. C'était une
            // affirmation commerciale faite à la place du client, et
            // potentiellement opposable. Il n'apparaît plus que s'il existe
            // un abonnement, avec son montant RÉELLEMENT convenu.
            LuxuryCard(
              highlighted: sub?.isBillable ?? false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClientSubscriptionScreen(),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sub?.isBillable ?? false
                            ? Icons.workspace_premium
                            : Icons.workspace_premium_outlined,
                        size: 18,
                        color: sub?.isBillable ?? false
                            ? AppColors.champagne
                            : AppColors.greyLight,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sub == null
                              ? 'Aucun abonnement en cours'
                              : (sub.tierName.isEmpty ? 'Formule' : sub.tierName),
                          style: AppTypography.title.copyWith(
                            letterSpacing: 1.2,
                            color: sub?.isBillable ?? false
                                ? AppColors.champagne
                                : AppColors.offWhite,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── DÉFAUT CORRIGÉ ───────────────────────────────────────
                  // Ce texte était `SubscriptionPolicy.closedNotice` sans la
                  // moindre condition. Depuis l'ouverture commerciale, un
                  // client sans contrat lisait donc ici « la souscription
                  // n'est pas encore ouverte », alors que l'écran suivant lui
                  // proposait « DEMANDER CETTE FORMULE » avec les tarifs. Deux
                  // affirmations incompatibles dans la même application.
                  // Le message suit désormais l'état réel de l'interrupteur.
                  Text(
                    sub == null
                        ? (SubscriptionPolicy.subscriptionsOpen
                              ? SubscriptionPolicy.openNotice
                              : SubscriptionPolicy.closedNotice)
                        : sub.status.description,
                    style: AppTypography.caption,
                  ),
                  if (sub != null) ...[
                    const Divider(height: 22),
                    InfoRow(label: 'Montant', value: sub.amountLabel),
                    const Divider(height: 1),
                    InfoRow(label: 'État', value: sub.status.label),
                  ],
                  if (sub == null) ...[
                    const Divider(height: 22),
                    // Même contradiction que ci-dessus, corrigée de la même
                    // façon : annoncer « dès l'ouverture officielle » alors que
                    // l'ouverture a eu lieu envoie le client attendre un
                    // événement déjà passé.
                    Text(
                      SubscriptionPolicy.subscriptionsOpen
                          ? 'Touchez cette carte ou « GÉRER MON ABONNEMENT » '
                                'pour consulter les formules et leurs tarifs.'
                          : 'Les formules vous seront présentées avec leurs '
                                'tarifs dès l\'ouverture officielle de la '
                                'souscription.',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClientSubscriptionScreen(),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_outlined, size: 15),
              label: const Text('GÉRER MON ABONNEMENT'),
            ),
            const SizedBox(height: 18),

            if (concierge != null)
              LuxuryCard(
                child: Row(
                  children: [
                    InitialsAvatar(initials: concierge.initials, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Concierge dédié',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10.5,
                            ),
                          ),
                          Text(
                            concierge.fullName,
                            style: AppTypography.title.copyWith(fontSize: 14),
                          ),
                          Text(
                            concierge.phone ?? '',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            SectionHeader(title: 'Langue de l\'application'),
            const SizedBox(height: 12),
            LuxuryCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: const LanguageTileList(),
            ),
            const SizedBox(height: 20),

            SectionHeader(title: 'Mes préférences'),
            const SizedBox(height: 12),
            LuxuryCard(
              child: Column(
                children: [
                  InfoRow(label: 'Langue', value: client.language),
                  const Divider(height: 1),
                  InfoRow(
                    label: 'Pays / Ville',
                    value: '${client.country} · ${client.city}',
                  ),
                  const Divider(height: 1),
                  InfoRow(label: 'E-mail', value: client.email),
                  const Divider(height: 1),
                  InfoRow(label: 'Téléphone', value: client.phone),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _prefCard(
              'Hôtels préférés',
              Icons.hotel_outlined,
              client.preferredHotels,
            ),
            _prefCard(
              'Restaurants préférés',
              Icons.restaurant_outlined,
              client.preferredRestaurants,
            ),
            _prefCard(
              'Chauffeurs préférés',
              Icons.directions_car_outlined,
              client.preferredDrivers,
            ),
            _prefCard(
              'Préférences de voyage',
              Icons.flight_takeoff_outlined,
              client.travelPreferences,
            ),
            _prefCard(
              'Préférences alimentaires',
              Icons.lunch_dining_outlined,
              client.dietaryPreferences,
            ),

            const SizedBox(height: 20),
            GoldButton(
              label: 'MODIFIER MES INFORMATIONS',
              icon: Icons.edit_outlined,
              fullWidth: true,
              onPressed: () => _editProfile(context, s),
            ),
            const SizedBox(height: 12),
            // Changement de mot de passe depuis l'espace personnel.
            // Auparavant, un client connecté n'avait AUCUN moyen de changer
            // son mot de passe : il devait se déconnecter et passer par
            // « mot de passe oublié », donc recevoir un e-mail.
            OutlinedButton.icon(
              onPressed: () => changeMyPassword(context),
              icon: const Icon(Icons.lock_reset_outlined, size: 15),
              label: const Text('CHANGER MON MOT DE PASSE'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  DocumentService.exportClientFile(context, s, client),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
              label: const Text('TÉLÉCHARGER MA FICHE (PDF)'),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.urgent,
                side: const BorderSide(color: AppColors.urgent, width: 0.8),
              ),
              onPressed: () => _contactGorex(context, s),
              icon: const Icon(Icons.emergency_outlined, size: 15),
              label: const Text('CONTACTER GOREX EN URGENCE'),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserGuideScreen()),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 15),
                label: const Text('GUIDE D\'UTILISATION'),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LegalHubScreen()),
                ),
                icon: const Icon(Icons.gavel_outlined, size: 15),
                label: const Text('INFORMATIONS LÉGALES'),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
                icon: const Icon(Icons.privacy_tip_outlined, size: 15),
                label: const Text('POLITIQUE DE CONFIDENTIALITÉ'),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                icon: const Icon(Icons.info_outline, size: 15),
                label: const Text('À PROPOS'),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => s.logout(),
                icon: const Icon(Icons.logout, size: 15),
                label: const Text('DÉCONNEXION'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _prefCard(String title, IconData icon, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LuxuryCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: AppColors.champagne),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: AppTypography.label.copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((e) => StatusPill(label: e, color: AppColors.greyLight))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre le formulaire d'édition des informations personnelles.
  Future<void> _editProfile(BuildContext context, AppState s) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MyAccountEditScreen()),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informations enregistrées sur le serveur. '
            'Vous les retrouverez à votre prochaine connexion.',
          ),
        ),
      );
    }
  }

  void _contactGorex(BuildContext context, AppState s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Contact d\'urgence', style: AppTypography.headline),
              const SizedBox(height: 6),
              Text(
                'Disponible 24/7 pour les membres GOREX PRIVATE et ELITE.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 18),
              LuxuryCard(
                child: Column(
                  children: [
                    // Les coordonnées proviennent du profil officiel Gorex Group
                    // saisi par la direction : plus aucun numéro d'exemple en dur.
                    InfoRow(label: 'Ligne 24/7', value: s.company.phone),
                    const Divider(height: 1),
                    InfoRow(label: 'E-mail', value: s.company.email),
                    const Divider(height: 1),
                    const InfoRow(
                      label: 'Concierge dédié',
                      value: 'Via la messagerie',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Fermer',
                fullWidth: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
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
