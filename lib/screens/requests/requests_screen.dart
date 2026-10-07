import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/service_request.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'request_detail_screen.dart';
import 'new_request_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _query = '';
  RequestStatus? _statusFilter;
  ServiceDomain? _domainFilter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = [...s.requests];
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (r) =>
                r.title.toLowerCase().contains(q) ||
                r.clientName.toLowerCase().contains(q) ||
                r.reference.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_statusFilter != null) {
      list = list.where((r) => r.status == _statusFilter).toList();
    }
    if (_domainFilter != null) {
      list = list.where((r) => r.domain == _domainFilter).toList();
    }
    list.sort((a, b) {
      final u = b.urgency.weight.compareTo(a.urgency.weight);
      if (u != 0) return u;
      return b.createdAt.compareTo(a.createdAt);
    });

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Demandes', style: AppTypography.displayMedium),
                          const SizedBox(height: 5),
                          Text(
                            '${s.openRequests} ouvertes · ${s.requests.length} au total',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    GoldButton(
                      label: 'Nouvelle',
                      icon: Icons.add,
                      onPressed: () => _openNew(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher par titre, client ou référence...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChipLux(
                        label: 'Toutes',
                        selected: _statusFilter == null,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...RequestStatus.values.map(
                        (st) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipLux(
                            label: st.label,
                            selected: _statusFilter == st,
                            onTap: () => setState(
                              () => _statusFilter = _statusFilter == st
                                  ? null
                                  : st,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChipLux(
                        label: 'Tous domaines',
                        selected: _domainFilter == null,
                        onTap: () => setState(() => _domainFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...ServiceDomain.values.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipLux(
                            label: d.label,
                            selected: _domainFilter == d,
                            onTap: () => setState(
                              () =>
                                  _domainFilter = _domainFilter == d ? null : d,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Aucune demande',
                    message: 'Aucune demande ne correspond à vos critères.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _RequestCard(request: list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _openNew(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewRequestScreen()),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    return LuxuryCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(requestId: request.id),
        ),
      ),
      borderColor: request.urgency.weight >= 2 ? AppColors.urgent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.anthracite,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      request.domain.icon,
                      size: 12,
                      color: AppColors.champagne,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      request.domain.label,
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (request.urgency.weight >= 1)
                StatusPill(
                  label: request.urgency.label,
                  color: request.urgency.color,
                  icon: request.urgency.weight >= 2
                      ? Icons.priority_high
                      : null,
                ),
              if (request.isSecurityEscalated) ...[
                const SizedBox(width: 6),
                StatusPill(
                  label: 'GOREX SECURITY',
                  color: AppColors.champagne,
                  icon: Icons.shield_outlined,
                ),
              ],
              const Spacer(),
              StatusPill(
                label: request.status.code,
                color: request.status.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.title,
            style: AppTypography.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            request.description,
            style: AppTypography.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.badge_outlined, request.reference),
              _meta(Icons.person_outline, request.clientName),
              _meta(
                Icons.event_outlined,
                DateFormat('dd MMM yyyy', 'fr_BE').format(request.date),
              ),
              _meta(Icons.schedule_outlined, request.time),
              _meta(Icons.place_outlined, request.location),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Budget: ${eur.format(request.budget)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.champagne,
                  ),
                ),
              ),
              if (request.responsibleName != null)
                Row(
                  children: [
                    const Icon(
                      Icons.support_agent,
                      size: 13,
                      color: AppColors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      request.responsibleName!,
                      style: AppTypography.caption,
                    ),
                  ],
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
