import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../requests/request_detail_screen.dart';
import '../communication/communication_screen.dart';

class ConciergeDashboard extends StatelessWidget {
  const ConciergeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.currentUser!;
    final myRequests =
        s.requests
            .where(
              (r) =>
                  r.responsibleId == user.id &&
                  r.status != RequestStatus.completed &&
                  r.status != RequestStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => b.urgency.weight.compareTo(a.urgency.weight));

    final today = DateTime.now();
    final todayAppointments = s.upcomingAppointments
        .where((a) => a.start.day == today.day && a.start.month == today.month)
        .toList();
    final myAppointments =
        s
            .appointmentsForUser(user.id)
            .where((a) => a.end.isAfter(today))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final myMessages = [...s.conversations]
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    final deadlines = s.upcomingAppointments
        .where(
          (a) =>
              a.type == AppointmentType.deadline ||
              a.type == AppointmentType.reminder,
        )
        .take(5)
        .toList();

    final urgent = myRequests.where((r) => r.urgency.weight >= 2).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${user.fullName.split(' ').first}',
              style: AppTypography.displayMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${user.title ?? user.role.label} · ${DateFormat.yMMMMd('fr_BE').format(today)}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),

            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 2 : 2);
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                final kpis = [
                  KpiTile(
                    label: 'Mes demandes',
                    value: '${myRequests.length}',
                    icon: Icons.inbox_outlined,
                  ),
                  KpiTile(
                    label: 'Prioritaires',
                    value: '${urgent.length}',
                    icon: Icons.priority_high,
                    accent: AppColors.urgent,
                  ),
                  KpiTile(
                    label: 'Tâches du jour',
                    value: '${todayAppointments.length}',
                    icon: Icons.today_outlined,
                  ),
                  KpiTile(
                    label: 'Rendez-vous',
                    value: '${myAppointments.length}',
                    icon: Icons.event_outlined,
                  ),
                ];
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: kpis
                      .map((k) => SizedBox(width: w, child: k))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 22),

            if (urgent.isNotEmpty) ...[
              LuxuryCard(
                highlighted: true,
                borderColor: AppColors.urgent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.urgent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'DEMANDES PRIORITAIRES',
                          style: AppTypography.eyebrow.copyWith(
                            color: AppColors.urgent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...urgent.map((r) => _RequestRow(r)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],

            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 780;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _listCard(
                      title: 'Mes demandes en cours',
                      icon: Icons.inbox_outlined,
                      empty: 'Aucune demande assignée',
                      children: myRequests
                          .take(6)
                          .map((r) => _RequestRow(r))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _listCard(
                      title: 'Tâches du jour',
                      icon: Icons.today_outlined,
                      empty: 'Aucune tâche aujourd\'hui',
                      children: todayAppointments
                          .map(
                            (a) => _ApptRow(
                              title: a.title,
                              sub: a.location ?? a.type.label,
                              time: DateFormat.Hm('fr_BE').format(a.start),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
                final right = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _listCard(
                      title: 'Messages récents',
                      icon: Icons.forum_outlined,
                      empty: 'Aucun message',
                      children: myMessages
                          .take(4)
                          .map(
                            (cv) => InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ConversationScreen(conversationId: cv.id),
                                ),
                              ),
                              child: _ApptRow(
                                title: cv.subject,
                                sub: cv.clientName,
                                time: DateFormat(
                                  'dd/MM',
                                ).format(cv.lastActivity),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _listCard(
                      title: 'Échéances & rappels',
                      icon: Icons.schedule_outlined,
                      empty: 'Aucune échéance',
                      children: deadlines
                          .map(
                            (a) => _ApptRow(
                              title: a.title,
                              sub: a.type.label,
                              time: DateFormat('dd/MM HH:mm').format(a.start),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 18),
                      Expanded(child: right),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [left, const SizedBox(height: 18), right],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _listCard({
    required String title,
    required IconData icon,
    required String empty,
    required List<Widget> children,
  }) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.champagne),
              const SizedBox(width: 10),
              Text(title, style: AppTypography.title),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(empty, style: AppTypography.caption),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final dynamic r;
  const _RequestRow(this.r);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: r.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(width: 3, height: 32, color: r.urgency.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.offWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.clientName} · ${r.subService}',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            StatusPill(label: r.status.code, color: r.status.color),
          ],
        ),
      ),
    );
  }
}

class _ApptRow extends StatelessWidget {
  final String title;
  final String sub;
  final String time;
  const _ApptRow({required this.title, required this.sub, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.anthracite,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.divider, width: 0.6),
            ),
            child: Center(
              child: Text(
                time,
                style: AppTypography.caption.copyWith(
                  color: AppColors.champagne,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.offWhite,
                  ),
                ),
                Text(
                  sub,
                  style: AppTypography.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
