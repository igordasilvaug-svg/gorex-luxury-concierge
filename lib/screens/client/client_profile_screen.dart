import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../documents/document_service.dart';
import '../legal/privacy_policy_screen.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final tier = s.tierById(client?.subscriptionTierId);
    final concierge = s.userById(client?.assignedConciergeId);
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );

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
                if (tier != null)
                  StatusPill(label: tier.name, color: AppColors.champagne),
                const SizedBox(width: 8),
                ConfidentialityBadge(level: client.confidentiality),
              ],
            ),
            const SizedBox(height: 20),

            if (tier != null)
              LuxuryCard(
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_outlined,
                          size: 18,
                          color: AppColors.champagne,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tier.name,
                          style: AppTypography.title.copyWith(
                            letterSpacing: 1.5,
                            color: AppColors.champagne,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(tier.tagline, style: AppTypography.caption),
                    const Divider(height: 22),
                    InfoRow(label: 'Demandes', value: tier.requestsLabel),
                    const Divider(height: 1),
                    InfoRow(label: 'Priorité', value: tier.priority),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'SLA réponse',
                      value: '< ${tier.responseMinutes} min',
                    ),
                    const Divider(height: 1),
                    InfoRow(label: 'Disponibilité', value: tier.availability),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Contrat annuel',
                      value: eur.format(tier.annualPrice),
                    ),
                  ],
                ),
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
                  children: const [
                    InfoRow(label: 'Ligne 24/7', value: '+32 2 555 01 99'),
                    Divider(height: 1),
                    InfoRow(label: 'E-mail', value: 'sos@gorex.com'),
                    Divider(height: 1),
                    InfoRow(
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
