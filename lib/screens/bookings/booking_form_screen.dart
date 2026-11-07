import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/provider_booking.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Formulaire de création / modification d'une réservation.
///
/// Une réservation engage contractuellement GOREX auprès du client ET du
/// prestataire : elle est donc enregistrée sur le serveur AVANT d'être
/// affichée. Si l'écriture échoue, l'écran reste ouvert et annonce l'échec —
/// il ne referme jamais en laissant croire à un enregistrement.
class BookingFormScreen extends StatefulWidget {
  /// Si non nul, on modifie une réservation existante.
  final Booking? existing;

  /// Client et demande éventuellement pré-sélectionnés (ouverture depuis une
  /// demande de service).
  final String? presetClientId;
  final String? presetRequestId;
  final String? presetTitle;

  const BookingFormScreen({
    super.key,
    this.existing,
    this.presetClientId,
    this.presetRequestId,
    this.presetTitle,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _providerPrice;
  late final TextEditingController _clientPrice;
  late final TextEditingController _notes;

  BookingType _type = BookingType.hotel;
  String? _clientId;
  String? _providerId;
  late DateTime _date;
  BookingStatus _status = BookingStatus.pending;
  bool _confirmed = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    final s = context.read<AppState>();

    _title = TextEditingController(text: b?.title ?? widget.presetTitle ?? '');
    _time = TextEditingController(text: b?.time ?? '20:00');
    _location = TextEditingController(text: b?.location ?? '');
    _providerPrice = TextEditingController(
      text: b == null ? '' : _formatAmount(b.providerPrice),
    );
    _clientPrice = TextEditingController(
      text: b == null ? '' : _formatAmount(b.clientPrice),
    );
    _notes = TextEditingController(text: b?.notes ?? '');

    _type = b?.type ?? BookingType.hotel;
    _status = b?.status ?? BookingStatus.pending;
    _confirmed = b?.confirmed ?? false;
    _date = b?.date ?? DateTime.now().add(const Duration(days: 1));

    // Un client ne peut réserver que pour lui-même : le sélecteur est alors
    // inutile et la valeur est verrouillée sur sa propre fiche.
    if (b != null) {
      _clientId = b.clientId;
      _providerId = b.providerId.isEmpty ? null : b.providerId;
    } else if (s.isStaff) {
      _clientId = widget.presetClientId ??
          (s.clients.isNotEmpty ? s.clients.first.id : null);
      // Pas de prestataire pré-sélectionné : le carnet peut être vide.
      _providerId = null;
    } else {
      _clientId = s.currentUser?.clientId;
    }
  }

  /// Affiche un montant sans décimales inutiles : « 250 » et non « 250.0 ».
  static String _formatAmount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [
      _title,
      _time,
      _location,
      _providerPrice,
      _clientPrice,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
      helpText: 'Date de la prestation',
      cancelText: 'ANNULER',
      confirmText: 'CHOISIR',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final s = context.read<AppState>();
    final client = s.clientById(_clientId);
    final provider = s.providerById(_providerId);

    // Le prix client ne peut pas être inférieur au coût fournisseur :
    // la marge deviendrait négative et la facturation incohérente.
    final pCost = double.tryParse(_providerPrice.text.trim()) ?? 0;
    final pSale = double.tryParse(_clientPrice.text.trim()) ?? 0;
    if (pSale < pCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le prix client ne peut pas être inférieur au coût fournisseur.',
          ),
          backgroundColor: AppColors.urgent,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final draft = Booking(
      id: widget.existing?.id ?? '',
      // La référence est calculée par AppState à la création (numéro suivant
      // le plus grand existant) ; en modification on conserve l'originale.
      reference: widget.existing?.reference ?? '',
      type: _type,
      clientId: _clientId ?? '',
      clientName: client?.fullName ?? widget.existing?.clientName ?? '',
      providerId: _providerId ?? '',
      providerName: provider?.name ?? widget.existing?.providerName ?? '',
      requestId: widget.existing?.requestId ?? widget.presetRequestId,
      title: _title.text.trim(),
      date: _date,
      time: _time.text.trim(),
      location: _location.text.trim(),
      providerPrice: pCost,
      clientPrice: pSale,
      // La marge est toujours recalculée : elle ne peut pas être saisie.
      commission: pSale - pCost,
      status: _status,
      confirmed: _confirmed,
      documentNames: widget.existing?.documentNames ?? const [],
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    try {
      if (_isEdit) {
        await s.updateBooking(draft);
      } else {
        await s.createBooking(draft);
      }
    } on CloudWriteException {
      // Rien n'a été enregistré : on ne referme pas l'écran pour ne pas
      // perdre la saisie, et on annonce clairement l'échec.
      if (!mounted) return;
      setState(() => _saving = false);
      showCloudFailure(
        context,
        _isEdit ? 'Modification de la réservation' : 'Création de la réservation',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eur = '€';

    // Un client ne voit pas les tarifs fournisseur ni la marge : ce sont des
    // données internes de GOREX.
    final showFinancials = s.isStaff;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Modifier la réservation' : 'Nouvelle réservation',
          style: AppTypography.title,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit
                      ? 'MISE À JOUR DE LA RÉSERVATION'
                      : 'CRÉATION D\'UNE RÉSERVATION',
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 8),
                const GoldDivider(width: 46),
                const SizedBox(height: 20),

                // ── Prestation ──
                _section('Prestation'),
                _label('Type de prestation'),
                _dropdown<BookingType>(
                  value: _type,
                  items: BookingType.values,
                  labelOf: (e) => e.label,
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 14),
                _label('Intitulé'),
                TextFormField(
                  controller: _title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Dîner au restaurant, transfert aéroport…',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Intitulé requis' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _dateField('Date'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Heure'),
                          TextFormField(
                            controller: _time,
                            keyboardType: TextInputType.datetime,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(hintText: '20:00'),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Heure requise';
                              final re = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');
                              if (!re.hasMatch(t)) {
                                return 'Format HH:MM';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Lieu'),
                TextFormField(
                  controller: _location,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Adresse ou nom du lieu',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Lieu requis'
                      : null,
                ),

                // ── Client ──
                _section('Client'),
                if (s.isStaff) ...[
                  _label('Client concerné'),
                  _dropdown<String>(
                    value: _clientId,
                    items: s.clients.map((c) => c.id).toList(),
                    labelOf: (id) {
                      final c = s.clientById(id);
                      return c == null
                          ? id
                          : (c.companyName != null && c.companyName!.isNotEmpty
                                ? '${c.fullName} · ${c.companyName}'
                                : c.fullName);
                    },
                    hint: s.clients.isEmpty
                        ? 'Aucun client enregistré'
                        : 'Sélectionner un client',
                    onChanged: (v) => setState(() => _clientId = v),
                    validator: (v) =>
                        v == null ? 'Client requis' : null,
                  ),
                  const SizedBox(height: 8),
                  if (s.clients.isEmpty)
                    Text(
                      'Créez d\'abord une fiche client : une réservation doit '
                      'être rattachée à un client identifié.',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        color: AppColors.statusWaiting,
                      ),
                    ),
                ] else
                  Text(
                    'Réservation au nom de ${s.currentUser?.fullName ?? 'votre compte'}.',
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),

                // ── Prestataire ──
                if (showFinancials) ...[
                  _section('Prestataire'),
                  _label('Fournisseur'),
                  // Facultatif VOLONTAIREMENT : le carnet de prestataires est
                  // vide sur une installation neuve (aucune donnée fictive en
                  // production). L'exiger rendrait toute réservation
                  // impossible. Le concierge peut l'affecter après coup ;
                  // il est alors enregistré sur le serveur comme le reste.
                  _dropdown<String>(
                    value: _providerId,
                    items: s.providers.map((p) => p.id).toList(),
                    labelOf: (id) {
                      final p = s.providerById(id);
                      if (p == null) return id;
                      return p.category.isEmpty
                          ? p.name
                          : '${p.name} · ${p.category}';
                    },
                    hint: s.providers.isEmpty
                        ? 'Non affecté (carnet prestataires vide)'
                        : 'Non affecté',
                    onChanged: (v) => setState(() => _providerId = v),
                  ),
                  if (_providerId == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        'La réservation sera créée sans prestataire affecté. '
                        'Vous pourrez l\'assigner depuis cet écran.',
                        style: AppTypography.caption.copyWith(fontSize: 10.5),
                      ),
                    ),

                  // ── Tarification ──
                  _section('Tarification'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Coût fournisseur ($eur)'),
                            TextFormField(
                              controller: _providerPrice,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.white,
                              ),
                              decoration: const InputDecoration(hintText: '0'),
                              onChanged: (_) => setState(() {}),
                              validator: _validateAmount,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Prix client ($eur)'),
                            TextFormField(
                              controller: _clientPrice,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.white,
                              ),
                              decoration: const InputDecoration(hintText: '0'),
                              onChanged: (_) => setState(() {}),
                              validator: _validateAmount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _marginPreview(),

                  // ── Suivi ──
                  _section('Suivi'),
                  _label('Statut'),
                  _dropdown<BookingStatus>(
                    value: _status,
                    items: BookingStatus.values,
                    labelOf: (e) => e.label,
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Réservation confirmée par le prestataire',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.white,
                        fontSize: 12.5,
                      ),
                    ),
                    activeThumbColor: AppColors.champagne,
                  ),
                ],

                // ── Notes ──
                _section('Notes internes'),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Consignes, préférences, informations utiles…',
                  ),
                ),

                const SizedBox(height: 26),
                GoldButton(
                  label: _isEdit ? 'Enregistrer' : 'Créer la réservation',
                  icon: _isEdit ? Icons.check : Icons.event_available,
                  fullWidth: true,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('ANNULER'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateAmount(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Montant requis';
    final d = double.tryParse(t.replaceAll(',', '.'));
    if (d == null) return 'Montant invalide';
    if (d < 0) return 'Montant négatif impossible';
    return null;
  }

  /// Aperçu de la marge, calculé en direct pendant la saisie.
  Widget _marginPreview() {
    final cost = double.tryParse(_providerPrice.text.trim().replaceAll(',', '.')) ?? 0;
    final sale = double.tryParse(_clientPrice.text.trim().replaceAll(',', '.')) ?? 0;
    final margin = sale - cost;
    final negative = margin < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.anthracite,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: negative ? AppColors.urgent : AppColors.divider,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Icon(
            negative ? Icons.warning_amber_outlined : Icons.trending_up,
            size: 15,
            color: negative ? AppColors.urgent : AppColors.champagne,
          ),
          const SizedBox(width: 10),
          Text(
            'Marge GOREX',
            style: AppTypography.caption.copyWith(fontSize: 10.5),
          ),
          const Spacer(),
          Text(
            '${_formatAmount(margin)} €',
            style: AppTypography.title.copyWith(
              fontSize: 14,
              color: negative ? AppColors.urgent : AppColors.champagne,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      InkWell(
        onTap: _pickDate,
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
                '${_date.day.toString().padLeft(2, '0')}/'
                '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
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

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 10)),
        const SizedBox(height: 8),
        const GoldDivider(width: 30),
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 7, left: 2),
    child: Text(
      t.toUpperCase(),
      style: AppTypography.label.copyWith(fontSize: 10),
    ),
  );

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      dropdownColor: AppColors.surfaceElevated,
      iconEnabledColor: AppColors.champagne,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
      decoration: InputDecoration(hintText: hint),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                labelOf(e),
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
