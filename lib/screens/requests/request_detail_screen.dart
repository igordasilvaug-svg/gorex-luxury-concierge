import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../communication/communication_screen.dart';
import '../documents/document_service.dart';

class RequestDetailScreen extends StatelessWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.requestById(requestId);
    if (r == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Introuvable',
          message: 'Cette demande n\'existe plus.',
        ),
      );
    }
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    final staff = s.isStaff;
    final linkedBookings = s.bookingsForRequest(r.id);
    final providers = r.providerIds
        .map((id) => s.providerById(id))
        .whereType<Object>()
        .toList();
    final conv = s.conversations.where((c) => c.requestId == r.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(r.reference, style: AppTypography.title),
        actions: [
          IconButton(
            tooltip: 'Exporter (PDF)',
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
            onPressed: () =>
                DocumentService.exportRequestSummary(context, s, r),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StatusPill(label: r.status.code, color: r.status.color),
                    const SizedBox(width: 8),
                    StatusPill(label: r.urgency.label, color: r.urgency.color),
                    if (r.isSecurityEscalated) ...[
                      const SizedBox(width: 8),
                      const StatusPill(
                        label: 'GOREX SECURITY',
                        color: AppColors.champagne,
                        icon: Icons.shield_outlined,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(r.title, style: AppTypography.displayMedium),
                const SizedBox(height: 8),
                Text(r.description, style: AppTypography.bodyLarge),
                const SizedBox(height: 20),

                LuxuryCard(
                  child: Column(
                    children: [
                      InfoRow(label: 'Client', value: r.clientName),
                      const Divider(height: 1),
                      InfoRow(label: 'Domaine', value: r.domain.label),
                      const Divider(height: 1),
                      InfoRow(label: 'Prestation', value: r.subService),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Date & heure',
                        value:
                            '${DateFormat('dd MMMM yyyy', 'fr_BE').format(r.date)} · ${r.time}',
                      ),
                      const Divider(height: 1),
                      InfoRow(label: 'Localisation', value: r.location),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Responsable',
                        value: r.responsibleName ?? 'Non assigné',
                      ),
                      const Divider(height: 1),
                      InfoRow(label: 'Budget', value: eur.format(r.budget)),
                      if (staff) ...[
                        const Divider(height: 1),
                        InfoRow(
                          label: 'Coût fournisseur',
                          value: eur.format(r.cost),
                        ),
                        const Divider(height: 1),
                        InfoRow(
                          label: 'Marge',
                          value:
                              '${eur.format(r.marginAmount)} (${r.marginPercent.toStringAsFixed(0)}%)',
                        ),
                      ],
                      if (r.escalationNote != null) ...[
                        const Divider(height: 1),
                        InfoRow(label: 'Escalade', value: r.escalationNote!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (staff) ...[
                  SectionHeader(title: 'Actions conciergerie'),
                  const SizedBox(height: 12),
                  _staffActions(context, s, r),
                  const SizedBox(height: 18),
                ],

                if (providers.isNotEmpty) ...[
                  SectionHeader(title: 'Prestataires mobilisés'),
                  const SizedBox(height: 12),
                  ...providers.map((p) {
                    final prov = p as dynamic;
                    return LuxuryCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.handshake_outlined,
                            size: 18,
                            color: AppColors.champagne,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prov.name,
                                  style: AppTypography.title.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${prov.category} · ${prov.city}, ${prov.country}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 18),
                ],

                if (linkedBookings.isNotEmpty) ...[
                  SectionHeader(title: 'Réservations liées'),
                  const SizedBox(height: 12),
                  ...linkedBookings.map(
                    (b) => LuxuryCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            b.type.icon,
                            size: 18,
                            color: AppColors.champagne,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title,
                                  style: AppTypography.title.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${b.reference} · ${DateFormat('dd/MM/yyyy', 'fr_BE').format(b.date)} ${b.time}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: b.status.label,
                            color: b.status.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                if (r.documentNames.isNotEmpty) ...[
                  SectionHeader(title: 'Documents'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: r.documentNames
                        .map(
                          (d) => StatusPill(
                            label: d,
                            color: AppColors.greyLight,
                            icon: Icons.description_outlined,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                ],

                if (conv.isNotEmpty) ...[
                  SectionHeader(title: 'Communication'),
                  const SizedBox(height: 12),
                  ...conv.map(
                    (c) => LuxuryCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ConversationScreen(conversationId: c.id),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            size: 18,
                            color: AppColors.champagne,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.subject,
                              style: AppTypography.title.copyWith(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${c.messages.length} msg',
                            style: AppTypography.caption,
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                SectionHeader(title: 'Historique'),
                const SizedBox(height: 12),
                LuxuryCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < r.history.length; i++) ...[
                        _historyRow(r.history[i], i == 0),
                        if (i < r.history.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyRow(dynamic h, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLast ? AppColors.champagne : AppColors.greyDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.action,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.offWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${h.actor} · ${DateFormat('dd/MM/yyyy HH:mm', 'fr_BE').format(h.timestamp)}',
                  style: AppTypography.caption.copyWith(fontSize: 10.5),
                ),
                if (h.detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    h.detail!,
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffActions(BuildContext context, AppState s, dynamic r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RequestStatus.values.map((st) {
            final sel = r.status == st;
            return InkWell(
              onTap: sel ? null : () => s.updateRequestStatus(r.id, st),
              borderRadius: BorderRadius.circular(3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? st.color.withValues(alpha: 0.16)
                      : AppColors.anthracite,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: sel ? st.color : AppColors.divider,
                    width: 0.7,
                  ),
                ),
                child: Text(
                  st.code,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                    color: sel ? st.color : AppColors.greyLight,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _assignSheet(context, s, r.id),
              icon: const Icon(Icons.person_add_alt, size: 15),
              label: const Text('ASSIGNER'),
            ),
            if (!r.isSecurityEscalated)
              OutlinedButton.icon(
                onPressed: () => s.escalateToSecurity(r.id),
                icon: const Icon(Icons.shield_outlined, size: 15),
                label: const Text('TRANSMETTRE GOREX SECURITY'),
              ),
            OutlinedButton.icon(
              onPressed: () =>
                  DocumentService.exportRequestSummary(context, s, r),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
              label: const Text('EXPORT PDF'),
            ),
          ],
        ),
      ],
    );
  }

  void _assignSheet(BuildContext context, AppState s, String requestId) {
    final staff = s.users.where((u) => u.role.isStaff).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: SectionHeader(title: 'Assigner à un concierge'),
            ),
            const Divider(height: 1),
            ...staff.map(
              (u) => ListTile(
                leading: InitialsAvatar(initials: u.initials, size: 36),
                title: Text(
                  u.fullName,
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
                subtitle: Text(u.role.label, style: AppTypography.caption),
                onTap: () {
                  s.assignRequest(requestId, u);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
