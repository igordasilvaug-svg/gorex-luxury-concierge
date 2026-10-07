import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ItineraryBuilderScreen extends StatefulWidget {
  const ItineraryBuilderScreen({super.key});

  @override
  State<ItineraryBuilderScreen> createState() => _ItineraryBuilderScreenState();
}

class _ItineraryBuilderScreenState extends State<ItineraryBuilderScreen> {
  final _title = TextEditingController();
  final _destination = TextEditingController();
  final _flight = TextEditingController();
  final _hotel = TextEditingController();
  final _transfer = TextEditingController();
  final _contact = TextEditingController();

  String? _clientId;
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  DateTime _end = DateTime.now().add(const Duration(days: 10));
  bool _security = false;
  final List<ItineraryItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    _flight.dispose();
    _hotel.dispose();
    _transfer.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    _clientId ??= s.clients.isNotEmpty ? s.clients.first.id : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Construire un itinéraire', style: AppTypography.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('CLIENT'),
                DropdownButtonFormField<String>(
                  initialValue: _clientId,
                  dropdownColor: AppColors.surfaceElevated,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  items: s.clients
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.fullName} — ${c.code}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _clientId = v),
                ),
                const SizedBox(height: 16),
                _label('TITRE'),
                TextField(
                  controller: _title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ex: Week-end privé à Paris',
                  ),
                ),
                const SizedBox(height: 16),
                _label('DESTINATION'),
                TextField(
                  controller: _destination,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Ville, pays'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        'DÉBUT',
                        _start,
                        (d) => setState(() => _start = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        'FIN',
                        _end,
                        (d) => setState(() => _end = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label('VOL'),
                TextField(
                  controller: _flight,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ex: Jet privé Nice → Paris 14:00',
                  ),
                ),
                const SizedBox(height: 16),
                _label('HÔTEL'),
                TextField(
                  controller: _hotel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ex: Le Bristol — Suite',
                  ),
                ),
                const SizedBox(height: 16),
                _label('TRANSFERTS'),
                TextField(
                  controller: _transfer,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ex: Mercedes S-Class + chauffeur',
                  ),
                ),
                const SizedBox(height: 16),
                _label('CONTACTS'),
                TextField(
                  controller: _contact,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Ex: Concierge: James +32... ; Chauffeur: Karim +32...',
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _security,
                  onChanged: (v) => setState(() => _security = v ?? false),
                  activeColor: AppColors.champagne,
                  checkColor: AppColors.black,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Inclure la coordination sécurité (GOREX SECURITY)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.offWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Programme',
                  subtitle: '${_items.length} étape(s)',
                  trailing: GoldButton(
                    label: 'Ajouter',
                    icon: Icons.add,
                    onPressed: () => _addItem(s),
                  ),
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  Text(
                    'Aucune étape. Ajoutez hôtels, restaurants, réunions, activités...',
                    style: AppTypography.caption,
                  )
                else
                  ..._items.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LuxuryCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              e.value.domain.icon,
                              size: 15,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.value.day} · ${e.value.time} · ${e.value.title}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.offWhite,
                                    ),
                                  ),
                                  Text(
                                    e.value.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  setState(() => _items.removeAt(e.key)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 26),
                GoldButton(
                  label: _saving
                      ? 'Génération...'
                      : 'Générer l\'itinéraire premium',
                  icon: Icons.auto_awesome,
                  fullWidth: true,
                  onPressed: _saving ? null : () => _save(s),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: AppTypography.label),
  );

  Widget _dateField(
    String label,
    DateTime value,
    ValueChanged<DateTime> onPick,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 1095)),
            );
            if (d != null) onPick(d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.anthracite,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.divider, width: 0.6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: AppColors.champagne,
                ),
                const SizedBox(width: 10),
                Text(
                  '${value.day}/${value.month}/${value.year}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addItem(AppState s) {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final timeC = TextEditingController(text: '12:00');
    ServiceDomain domain = ServiceDomain.travel;

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
              Text('Ajouter une étape', style: AppTypography.headline),
              const SizedBox(height: 16),
              DropdownButtonFormField<ServiceDomain>(
                initialValue: domain,
                dropdownColor: AppColors.surfaceElevated,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'TYPE'),
                items: ServiceDomain.values
                    .map(
                      (d) => DropdownMenuItem(value: d, child: Text(d.label)),
                    )
                    .toList(),
                onChanged: (v) => setSheet(() => domain = v ?? domain),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleC,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'TITRE'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descC,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'DESCRIPTION'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeC,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(labelText: 'HEURE (HH:mm)'),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Ajouter',
                fullWidth: true,
                onPressed: () {
                  if (titleC.text.trim().isEmpty) return;
                  final day = _items.length + 1;
                  setState(() {
                    _items.add(
                      ItineraryItem(
                        id: 'ii_${DateTime.now().microsecondsSinceEpoch}',
                        day: 'Day $day',
                        time: timeC.text.trim(),
                        title: titleC.text.trim(),
                        description: descC.text.trim(),
                        domain: domain,
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(AppState s) async {
    if (_title.text.trim().isEmpty || _clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseignez le titre et le client.')),
      );
      return;
    }
    setState(() => _saving = true);
    final client = s.clientById(_clientId);
    final contacts = _contact.text
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await s.createItinerary(
      Itinerary(
        id: '',
        reference: '',
        clientId: _clientId!,
        clientName: client?.fullName ?? 'Client',
        title: _title.text.trim(),
        destination: _destination.text.trim().isEmpty
            ? 'À préciser'
            : _destination.text.trim(),
        startDate: _start,
        endDate: _end,
        items: _items,
        flightInfo: _flight.text.trim().isEmpty ? null : _flight.text.trim(),
        hotelInfo: _hotel.text.trim().isEmpty ? null : _hotel.text.trim(),
        transferInfo: _transfer.text.trim().isEmpty
            ? null
            : _transfer.text.trim(),
        contacts: contacts,
        securityIncluded: _security,
        status: RequestStatus.underReview,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Itinéraire premium généré.')));
  }
}
