import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/client.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../access/member_form_screen.dart';
import '../documents/document_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = [...s.clients];
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (c) =>
                c.fullName.toLowerCase().contains(q) ||
                c.code.toLowerCase().contains(q) ||
                (c.companyName?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clients VIP', style: AppTypography.displayMedium),
                const SizedBox(height: 5),
                Text(
                  '${s.clients.length} profils confidentiels',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un client...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ClientCard(client: list[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Client client;
  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final tier = s.tierById(client.subscriptionTierId);
    final concierge = s.userById(client.assignedConciergeId);
    return LuxuryCard(
      onTap: () => _showDetail(context, s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: _initials(client.fullName), size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.fullName, style: AppTypography.title),
                    const SizedBox(height: 2),
                    Text(
                      '${client.code} · ${client.category.label}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    label: tier?.name.replaceFirst('GOREX ', '') ?? '—',
                    color: AppColors.champagne,
                  ),
                  const SizedBox(height: 6),
                  ConfidentialityBadge(level: client.confidentiality),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.place_outlined, '${client.city}, ${client.country}'),
              _meta(Icons.translate, client.language),
              if (concierge != null)
                _meta(Icons.support_agent, concierge.fullName),
            ],
          ),
          if (client.companyName != null) ...[
            const SizedBox(height: 8),
            Text(
              client.companyName!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.grey),
      const SizedBox(width: 5),
      Text(t, style: AppTypography.caption.copyWith(fontSize: 10.5)),
    ],
  );

  void _showDetail(BuildContext context, AppState s) {
    final tier = s.tierById(client.subscriptionTierId);
    final concierge = s.userById(client.assignedConciergeId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InitialsAvatar(
                    initials: _initials(client.fullName),
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.fullName, style: AppTypography.headline),
                        Text(
                          '${client.code} · ${client.category.label}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  ConfidentialityBadge(level: client.confidentiality),
                ],
              ),
              const SizedBox(height: 18),
              LuxuryCard(
                child: Column(
                  children: [
                    InfoRow(label: 'Abonnement', value: tier?.name ?? '—'),
                    const Divider(height: 1),
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
                    if (client.secondaryContact != null) ...[
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Contact 2',
                        value: client.secondaryContact!,
                      ),
                    ],
                    if (client.personalAssistant != null) ...[
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Assistant(e)',
                        value: client.personalAssistant!,
                      ),
                    ],
                    if (client.assistantPhone != null) ...[
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Tel assistant',
                        value: client.assistantPhone!,
                      ),
                    ],
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Concierge dédié',
                      value: concierge?.fullName ?? 'Non assigné',
                    ),
                  ],
                ),
              ),
              if (client.preferredHotels.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chipSection('Hôtels préférés', client.preferredHotels),
              ],
              if (client.preferredRestaurants.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chipSection(
                  'Restaurants préférés',
                  client.preferredRestaurants,
                ),
              ],
              if (client.preferredDrivers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chipSection('Chauffeurs préférés', client.preferredDrivers),
              ],
              if (client.travelPreferences.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chipSection('Préférences de voyage', client.travelPreferences),
              ],
              if (client.dietaryPreferences.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chipSection(
                  'Préférences alimentaires',
                  client.dietaryPreferences,
                ),
              ],
              if (client.interests.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chipSection('Centres d\'intérêt', client.interests),
              ],
              if (client.notes != null) ...[
                const SizedBox(height: 16),
                Text('NOTES CONFIDENTIELLES', style: AppTypography.label),
                const SizedBox(height: 6),
                Text(client.notes!, style: AppTypography.bodyMedium),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () =>
                    DocumentService.exportClientFile(context, s, client),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                label: const Text('EXPORTER FICHE CLIENT (PDF)'),
              ),
              if (s.can('user_access')) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _createClientAccess(context, s),
                  icon: const Icon(Icons.vpn_key_outlined, size: 15),
                  label: Text(
                    _hasAccess(s)
                        ? 'ACCÈS CLIENT EXISTANT'
                        : 'CRÉER UN ACCÈS CLIENT VIP',
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasAccess(AppState s) =>
      s.clientUsers.any((u) => u.clientId == client.id);

  void _createClientAccess(BuildContext context, AppState s) {
    final existing = s.clientUsers.where((u) => u.clientId == client.id).toList();
    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce client possède déjà un accès : ${existing.first.email}',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(clientId: client.id),
      ),
    );
  }

  Widget _chipSection(String title, List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title.toUpperCase(), style: AppTypography.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((e) => StatusPill(label: e, color: AppColors.greyLight))
            .toList(),
      ),
    ],
  );

  static String _initials(String name) {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
