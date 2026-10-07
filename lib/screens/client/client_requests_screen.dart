import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../requests/request_detail_screen.dart';
import 'ask_gorex_screen.dart';

class ClientRequestsScreen extends StatelessWidget {
  const ClientRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final requests = s.myRequests;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mes demandes', style: AppTypography.displayMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${requests.length} demande(s)',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                GoldButton(
                  label: 'Ask Gorex',
                  icon: Icons.auto_awesome,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AskGorexScreen()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Aucune demande',
                    message: 'Faites votre première demande via « Ask Gorex ».',
                    action: GoldButton(
                      label: 'Ask Gorex',
                      icon: Icons.auto_awesome,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AskGorexScreen(),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = requests[i];
                      return LuxuryCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RequestDetailScreen(requestId: r.id),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  r.domain.icon,
                                  size: 15,
                                  color: AppColors.champagne,
                                ),
                                const SizedBox(width: 8),
                                Text(r.reference, style: AppTypography.caption),
                                const Spacer(),
                                StatusPill(
                                  label: r.status.label,
                                  color: r.status.color,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              r.title,
                              style: AppTypography.title.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 5),
                            Text(r.subService, style: AppTypography.bodyMedium),
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
                                  DateFormat(
                                    'dd MMM yyyy',
                                    'fr_BE',
                                  ).format(r.date),
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
                                    r.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (r.urgency.weight >= 1) ...[
                              const SizedBox(height: 10),
                              StatusPill(
                                label: r.urgency.label,
                                color: r.urgency.color,
                              ),
                            ],
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
