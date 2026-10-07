import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ClientBookingsScreen extends StatelessWidget {
  const ClientBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final bookings = client != null
        ? (s.bookingsForClient(client.id)
            ..sort((a, b) => a.date.compareTo(b.date)))
        : [];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mes réservations', style: AppTypography.displayMedium),
                const SizedBox(height: 4),
                Text(
                  '${bookings.length} réservation(s)',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: bookings.isEmpty
                ? const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Aucune réservation',
                    message: 'Vos réservations confirmées apparaîtront ici.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final b = bookings[i];
                      return LuxuryCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  b.type.icon,
                                  size: 16,
                                  color: AppColors.champagne,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  b.type.label,
                                  style: AppTypography.caption,
                                ),
                                const Spacer(),
                                StatusPill(
                                  label: b.status.label,
                                  color: b.status.color,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              b.title,
                              style: AppTypography.title.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              b.providerName,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.champagne,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_outlined,
                                  size: 12,
                                  color: AppColors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${DateFormat('dd MMM yyyy', 'fr_BE').format(b.date)} · ${b.time}',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10.5,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.place_outlined,
                                  size: 12,
                                  color: AppColors.grey,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    b.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
