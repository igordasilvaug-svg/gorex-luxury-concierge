import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final upcoming = s.upcomingAppointments;

    // Grouper par jour
    final Map<String, List> grouped = {};
    for (final a in upcoming) {
      final key = DateFormat('EEEE d MMMM yyyy', 'fr_BE').format(a.start);
      grouped.putIfAbsent(key, () => []).add(a);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agenda', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Text(
              'Rendez-vous · voyages · réservations · missions · échéances',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),
            if (upcoming.isEmpty)
              const EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Agenda vide',
                message: 'Aucun événement à venir.',
              )
            else
              ...grouped.entries.map(
                (e) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            e.key.toUpperCase(),
                            style: AppTypography.eyebrow.copyWith(
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Divider(height: 1)),
                        ],
                      ),
                    ),
                    ...e.value.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LuxuryCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.champagne.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  a.type.icon,
                                  size: 18,
                                  color: AppColors.champagne,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: AppTypography.title.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${DateFormat.Hm('fr_BE').format(a.start)} — ${DateFormat.Hm('fr_BE').format(a.end)}'
                                      '${a.location != null ? ' · ${a.location}' : ''}',
                                      style: AppTypography.caption,
                                    ),
                                    if (a.clientName != null)
                                      Text(
                                        a.clientName!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.champagne,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusPill(
                                    label: a.type.label.split(' ').first,
                                    color: AppColors.greyLight,
                                  ),
                                  if (a.reminderSet) ...[
                                    const SizedBox(height: 6),
                                    const Icon(
                                      Icons.alarm,
                                      size: 13,
                                      color: AppColors.champagne,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
