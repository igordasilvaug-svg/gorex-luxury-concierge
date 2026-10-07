import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../communication/communication_screen.dart';

class ClientMessagesScreen extends StatelessWidget {
  const ClientMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final convs = [...s.myConversations]
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mon concierge', style: AppTypography.displayMedium),
                const SizedBox(height: 4),
                Text(
                  'Communication directe et confidentielle',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: convs.isEmpty
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Aucune conversation',
                    message:
                        'Vos échanges avec votre concierge apparaîtront ici.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                    itemCount: convs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = convs[i];
                      final last =
                          c.messages.where((m) => !m.internal).isNotEmpty
                          ? c.messages.where((m) => !m.internal).last
                          : null;
                      return LuxuryCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ConversationScreen(conversationId: c.id),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              size: 20,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.subject,
                                    style: AppTypography.title.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    last != null
                                        ? '${last.senderName}: ${last.text}'
                                        : 'Aucun message',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat('dd/MM').format(c.lastActivity),
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.grey,
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
