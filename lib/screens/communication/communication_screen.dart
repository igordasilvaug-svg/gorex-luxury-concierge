import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class CommunicationScreen extends StatelessWidget {
  const CommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = [...s.conversations]
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Communication', style: AppTypography.displayMedium),
                const SizedBox(height: 5),
                Text(
                  'Messagerie interne · client · concierge · direction · prestataire',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GoldButton(
                    label: 'Nouvelle conversation',
                    icon: Icons.add_comment_outlined,
                    onPressed: () => _newConversation(context, s),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Aucune conversation',
                    message:
                        'Démarrez une conversation avec un client ou prestataire.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _ConversationCard(conv: list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _newConversation(BuildContext context, AppState s) {
    final subject = TextEditingController();
    String? clientId = s.clients.isNotEmpty ? s.clients.first.id : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouvelle conversation', style: AppTypography.headline),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: clientId,
                dropdownColor: AppColors.surfaceElevated,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'CLIENT'),
                items: s.clients
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSheet(() => clientId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subject,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'SUJET'),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Créer',
                fullWidth: true,
                onPressed: () async {
                  if (subject.text.trim().isEmpty || clientId == null) return;
                  await s.createConversation(
                    subject: subject.text.trim(),
                    clientId: clientId!,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final dynamic conv;
  const _ConversationCard({required this.conv});

  @override
  Widget build(BuildContext context) {
    final last = conv.messages.isNotEmpty ? conv.messages.last : null;
    return LuxuryCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(conversationId: conv.id),
        ),
      ),
      child: Row(
        children: [
          InitialsAvatar(initials: _initials(conv.clientName), size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conv.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM HH:mm').format(conv.lastActivity),
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  conv.clientName,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagne,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  last != null
                      ? '${last.senderName}: ${last.text}'
                      : 'Aucun message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p.first[0]}${p.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  const ConversationScreen({super.key, required this.conversationId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _msg = TextEditingController();
  bool _internal = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final conv = s.conversations.firstWhere(
      (c) => c.id == widget.conversationId,
      orElse: () => s.conversations.first,
    );
    final staff = s.isStaff;
    final visible = staff
        ? conv.messages
        : conv.messages.where((m) => !m.internal).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conv.subject,
              style: AppTypography.title.copyWith(fontSize: 15),
            ),
            Text(
              conv.clientName,
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final m = visible[i];
                  final mine = m.senderId == s.currentUser?.id;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 460),
                      decoration: BoxDecoration(
                        color: m.internal
                            ? AppColors.champagne.withValues(alpha: 0.08)
                            : mine
                            ? AppColors.champagne.withValues(alpha: 0.14)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: m.internal
                              ? AppColors.champagneDark
                              : mine
                              ? AppColors.champagneDark
                              : AppColors.divider,
                          width: 0.6,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                m.senderName,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.champagne,
                                  fontSize: 10.5,
                                ),
                              ),
                              if (m.internal) ...[
                                const SizedBox(width: 6),
                                const StatusPill(
                                  label: 'Interne',
                                  color: AppColors.champagne,
                                ),
                              ],
                              const Spacer(),
                              Text(
                                DateFormat('dd/MM HH:mm').format(m.timestamp),
                                style: AppTypography.caption.copyWith(
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.text,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.offWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.blackSoft,
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.6),
                ),
              ),
              child: Column(
                children: [
                  if (staff)
                    Row(
                      children: [
                        Checkbox(
                          value: _internal,
                          onChanged: (v) =>
                              setState(() => _internal = v ?? false),
                          activeColor: AppColors.champagne,
                          checkColor: AppColors.black,
                        ),
                        Text(
                          'Note interne (visible équipe uniquement)',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msg,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Écrire un message...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.champagne,
                        ),
                        icon: const Icon(
                          Icons.send,
                          size: 18,
                          color: AppColors.black,
                        ),
                        onPressed: () async {
                          if (_msg.text.trim().isEmpty) return;
                          await s.sendMessage(
                            conv.id,
                            _msg.text.trim(),
                            internal: _internal,
                          );
                          _msg.clear();
                          setState(() => _internal = false);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
