import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/provider_booking.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'booking_form_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  BookingType? _filter;

  /// Ouvre le formulaire de réservation (création ou modification).
  Future<void> _openForm([Booking? existing]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingFormScreen(existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = [...s.bookings];
    if (_filter != null) list = list.where((b) => b.type == _filter).toList();
    list.sort((a, b) => a.date.compareTo(b.date));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Réservations', style: AppTypography.displayMedium),
                const SizedBox(height: 5),
                Text(
                  '${s.bookings.length} réservations · gestion fournisseurs & marges',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 14),
                // Le bouton est présent même sans réservation : sans lui,
                // la première réservation ne pouvait pas être créée.
                GoldButton(
                  label: 'Nouvelle réservation',
                  icon: Icons.add,
                  onPressed: () => _openForm(),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChipLux(
                        label: 'Toutes',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      const SizedBox(width: 8),
                      ...BookingType.values.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipLux(
                            label: t.label,
                            selected: _filter == t,
                            onTap: () => setState(
                              () => _filter = _filter == t ? null : t,
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
                ? EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Aucune réservation',
                    message: s.bookings.isEmpty
                        ? 'Créez la première réservation avec le bouton ci-dessus.'
                        : 'Aucune réservation pour ce filtre.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _BookingCard(
                      b: list[i],
                      onTap: () => _openForm(list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking b;
  final VoidCallback onTap;
  const _BookingCard({required this.b, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 0,
    );
    return InkWell(
      onTap: onTap,
      child: LuxuryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(b.type.icon, size: 16, color: AppColors.champagne),
                const SizedBox(width: 10),
                Text(b.reference, style: AppTypography.caption),
                const Spacer(),
                StatusPill(label: b.status.label, color: b.status.color),
              ],
            ),
            const SizedBox(height: 10),
            Text(b.title, style: AppTypography.title),
            const SizedBox(height: 5),
            Text(
              b.providerName,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.champagne,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _meta(Icons.person_outline, b.clientName),
                _meta(
                  Icons.event_outlined,
                  DateFormat('dd/MM/yyyy', 'fr_BE').format(b.date),
                ),
                _meta(Icons.schedule_outlined, b.time),
                _meta(Icons.place_outlined, b.location),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prix client',
                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                      Text(
                        eur.format(b.clientPrice),
                        style: AppTypography.title.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coût fournisseur',
                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                      Text(
                        eur.format(b.providerPrice),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.greyLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marge',
                        style: AppTypography.caption.copyWith(fontSize: 10),
                      ),
                      Text(
                        eur.format(b.margin),
                        style: AppTypography.title.copyWith(
                          fontSize: 15,
                          color: AppColors.champagne,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (b.confirmed) ...[
              const SizedBox(height: 10),
              const StatusPill(
                label: 'Confirmée',
                color: AppColors.statusConfirmed,
                icon: Icons.check_circle_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.grey),
      const SizedBox(width: 5),
      Text(t, style: AppTypography.caption.copyWith(fontSize: 10.5)),
    ],
  );
}
