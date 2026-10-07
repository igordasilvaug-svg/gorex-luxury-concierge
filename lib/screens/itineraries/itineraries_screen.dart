import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

import '../../models/itinerary.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../documents/document_service.dart';
import 'itinerary_builder_screen.dart';

class ItinerariesScreen extends StatelessWidget {
  const ItinerariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = [...s.itineraries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Itinéraires', style: AppTypography.displayMedium),
                      const SizedBox(height: 5),
                      Text(
                        'Construction de voyages premium · export PDF',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                GoldButton(
                  label: 'Construire',
                  icon: Icons.add,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ItineraryBuilderScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.map_outlined,
                    title: 'Aucun itinéraire',
                    message: 'Construisez votre premier voyage premium.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _ItineraryCard(itinerary: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;
  const _ItineraryCard({required this.itinerary});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return LuxuryCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItineraryDetailScreen(itineraryId: itinerary.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.map_outlined,
                size: 16,
                color: AppColors.champagne,
              ),
              const SizedBox(width: 10),
              Text(itinerary.reference, style: AppTypography.caption),
              const Spacer(),
              StatusPill(
                label: itinerary.status.code,
                color: itinerary.status.color,
              ),
              if (itinerary.securityIncluded) ...[
                const SizedBox(width: 6),
                const StatusPill(
                  label: 'SÉCURITÉ',
                  color: AppColors.champagne,
                  icon: Icons.shield_outlined,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(itinerary.title, style: AppTypography.title),
          const SizedBox(height: 4),
          Text(
            '${itinerary.destination} · ${DateFormat('dd MMM', 'fr_BE').format(itinerary.startDate)} — ${DateFormat('dd MMM yyyy', 'fr_BE').format(itinerary.endDate)}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.person_outline, itinerary.clientName),
              _meta(Icons.list_alt, '${itinerary.items.length} étapes'),
              if (itinerary.contacts.isNotEmpty)
                _meta(
                  Icons.contact_phone_outlined,
                  '${itinerary.contacts.length} contacts',
                ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Client: ${itinerary.clientName}',
                  style: AppTypography.caption,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    DocumentService.exportItinerary(context, s, itinerary),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                label: const Text('PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.grey),
      const SizedBox(width: 5),
      Text(text, style: AppTypography.caption.copyWith(fontSize: 10.5)),
    ],
  );
}

class ItineraryDetailScreen extends StatelessWidget {
  final String itineraryId;
  const ItineraryDetailScreen({super.key, required this.itineraryId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final it = s.itineraryById(itineraryId);
    if (it == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Introuvable',
          message: 'Itinéraire supprimé.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(it.reference, style: AppTypography.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
            onPressed: () => DocumentService.exportItinerary(context, s, it),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(it.title, style: AppTypography.displayMedium),
                const SizedBox(height: 6),
                Text(
                  it.destination,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.champagne,
                  ),
                ),
                const SizedBox(height: 18),
                LuxuryCard(
                  child: Column(
                    children: [
                      InfoRow(
                        label: 'Dates',
                        value:
                            '${DateFormat('dd MMM', 'fr_BE').format(it.startDate)} — ${DateFormat('dd MMM yyyy', 'fr_BE').format(it.endDate)}',
                      ),
                      if (it.flightInfo != null) ...[
                        const Divider(height: 1),
                        InfoRow(label: 'Vol', value: it.flightInfo!),
                      ],
                      if (it.hotelInfo != null) ...[
                        const Divider(height: 1),
                        InfoRow(label: 'Hébergement', value: it.hotelInfo!),
                      ],
                      if (it.transferInfo != null) ...[
                        const Divider(height: 1),
                        InfoRow(label: 'Transferts', value: it.transferInfo!),
                      ],
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Sécurité',
                        value: it.securityIncluded
                            ? 'Coordination GOREX SECURITY'
                            : 'Non incluse',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(title: 'Programme (${it.items.length} étapes)'),
                const SizedBox(height: 12),
                ...it.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LuxuryCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.anthracite,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: AppColors.divider,
                                width: 0.6,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  item.day,
                                  style: AppTypography.eyebrow.copyWith(
                                    fontSize: 8,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.time,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.champagne,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      item.domain.icon,
                                      size: 13,
                                      color: AppColors.champagne,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: AppTypography.title.copyWith(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: AppTypography.bodyMedium,
                                ),
                                if (item.contact != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'Contact : ${item.contact}',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (it.contacts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SectionHeader(title: 'Contacts clés'),
                  const SizedBox(height: 12),
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: it.contacts
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.contact_phone_outlined,
                                    size: 14,
                                    color: AppColors.champagne,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c,
                                      style: AppTypography.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
