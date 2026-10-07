import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/animations.dart';
import '../../widgets/common.dart';
import 'ask_gorex_screen.dart';
import 'client_requests_screen.dart';
import 'client_messages_screen.dart';
import '../requests/request_detail_screen.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final requests = s.myRequests;
    final bookings = client != null ? s.bookingsForClient(client.id) : [];
    final upcoming =
        s
            .appointmentsForClient(client?.id ?? '')
            .where((a) => a.end.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final tier = s.tierById(client?.subscriptionTierId);
    final concierge = s.userById(client?.assignedConciergeId);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.champagne,
        onRefresh: () async =>
            await Future.delayed(const Duration(milliseconds: 400)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bienvenue,', style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(
                client?.fullName.split(' ').first ?? 'Cher membre',
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (tier != null)
                    StatusPill(label: tier.name, color: AppColors.champagne),
                  const SizedBox(width: 8),
                  ConfidentialityBadge(
                    level:
                        client?.confidentiality ??
                        ConfidentialityLevel.elevated,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ask Gorex CTA
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AskGorexScreen()),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.champagne.withValues(alpha: 0.18),
                        AppColors.surfaceElevated,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.champagneDark,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.champagne,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.black,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ASK GOREX',
                              style: AppTypography.title.copyWith(
                                letterSpacing: 2,
                                color: AppColors.champagne,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Exprimez votre demande — votre concierge s\'en occupe.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppColors.champagne,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Urgence — halo pulsant discret
              PulseGlow(
                color: AppColors.urgent,
                child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AskGorexScreen(urgent: true),
                  ),
                ),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.urgent.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emergency_outlined,
                        color: AppColors.urgent,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'URGENT / PRIORITY REQUEST',
                              style: AppTypography.label.copyWith(
                                color: AppColors.urgent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Alerte immédiate de votre concierge et de la direction.',
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
              ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: KpiTile(
                      label: 'Demandes actives',
                      value:
                          '${requests.where((r) => r.status != RequestStatus.completed && r.status != RequestStatus.cancelled).length}',
                      icon: Icons.inbox_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiTile(
                      label: 'Réservations',
                      value: '${bookings.length}',
                      icon: Icons.event_available_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (concierge != null)
                LuxuryCard(
                  child: Row(
                    children: [
                      AnimatedRingAvatar(initials: concierge.initials, size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Votre concierge dédié',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              concierge.fullName,
                              style: AppTypography.title,
                            ),
                            Text(
                              concierge.title ?? concierge.role.label,
                              style: AppTypography.caption.copyWith(
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.champagne,
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 17,
                          color: AppColors.black,
                        ),
                        onPressed: () {
                          final convs = s.myConversations;
                          if (convs.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClientMessagesScreen(),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClientMessagesScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),

              SectionHeader(
                title: 'Demandes récentes',
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClientRequestsScreen(),
                    ),
                  ),
                  child: const Text('TOUT VOIR'),
                ),
              ),
              const SizedBox(height: 10),
              if (requests.isEmpty)
                LuxuryCard(
                  child: Text(
                    'Aucune demande pour le moment. Utilisez « Ask Gorex ».',
                    style: AppTypography.caption,
                  ),
                )
              else
                ...requests
                    .take(3)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LuxuryCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestDetailScreen(requestId: r.id),
                            ),
                          ),
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 38,
                                color: r.urgency.color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.title.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${r.domain.label} · ${DateFormat('dd MMM', 'fr_BE').format(r.date)}',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: r.status.label,
                                color: r.status.color,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 18),

              if (upcoming.isNotEmpty) ...[
                SectionHeader(title: 'Prochains rendez-vous'),
                const SizedBox(height: 10),
                ...upcoming
                    .take(3)
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LuxuryCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                a.type.icon,
                                size: 16,
                                color: AppColors.champagne,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.offWhite,
                                      ),
                                    ),
                                    Text(
                                      '${DateFormat('dd MMM HH:mm', 'fr_BE').format(a.start)}'
                                      '${a.location != null ? ' · ${a.location}' : ''}',
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
                      ),
                    ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
