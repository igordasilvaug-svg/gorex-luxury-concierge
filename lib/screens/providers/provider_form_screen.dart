import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/provider_booking.dart' as model;
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Formulaire de création / modification d'un prestataire (fournisseur).
///
/// Un prestataire engage GOREX : son tarif et sa commission déterminent
/// directement la marge des réservations. La fiche est donc enregistrée sur
/// le serveur AVANT d'être affichée ; en cas de refus, l'écran reste ouvert
/// et annonce l'échec plutôt que de laisser croire à un enregistrement.
class ProviderFormScreen extends StatefulWidget {
  /// Si non nul, on modifie une fiche existante.
  final model.Provider? existing;

  const ProviderFormScreen({super.key, this.existing});

  @override
  State<ProviderFormScreen> createState() => _ProviderFormScreenState();
}

class _ProviderFormScreenState extends State<ProviderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _contactName;
  late final TextEditingController _contactEmail;
  late final TextEditingController _contactPhone;
  late final TextEditingController _rate;
  late final TextEditingController _commission;
  late final TextEditingController _documents;
  late final TextEditingController _notes;

  ServiceDomain _domain = ServiceDomain.travel;
  int _trustLevel = 4;
  bool _active = true;
  bool _hasContract = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;

    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _country = TextEditingController(text: p?.country ?? 'Belgique');
    _city = TextEditingController(text: p?.city ?? '');
    _contactName = TextEditingController(text: p?.contactName ?? '');
    _contactEmail = TextEditingController(text: p?.contactEmail ?? '');
    _contactPhone = TextEditingController(text: p?.contactPhone ?? '');
    _rate = TextEditingController(text: p == null ? '' : _formatAmount(p.rate));
    _commission = TextEditingController(
      text: p == null ? '10' : _formatAmount(p.commissionPercent),
    );
    _documents = TextEditingController(text: p?.documentNames.join('; ') ?? '');
    _notes = TextEditingController(text: p?.internalNotes ?? '');

    _domain = p?.domain ?? ServiceDomain.travel;
    _trustLevel = p?.trustLevel ?? 4;
    _active = p?.active ?? true;
    _hasContract = p?.hasContract ?? false;
  }

  static String _formatAmount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [
      _name,
      _category,
      _country,
      _city,
      _contactName,
      _contactEmail,
      _contactPhone,
      _rate,
      _commission,
      _documents,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final s = context.read<AppState>();
    setState(() => _saving = true);

    final draft = model.Provider(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      category: _category.text.trim(),
      domain: _domain,
      country: _country.text.trim(),
      city: _city.text.trim(),
      contactName: _contactName.text.trim(),
      contactEmail: _contactEmail.text.trim(),
      contactPhone: _contactPhone.text.trim(),
      rate: double.tryParse(_rate.text.trim().replaceAll(',', '.')) ?? 0,
      commissionPercent:
          double.tryParse(_commission.text.trim().replaceAll(',', '.')) ?? 0,
      trustLevel: _trustLevel,
      active: _active,
      documentNames: _documents.text
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      hasContract: _hasContract,
      internalNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    try {
      if (_isEdit) {
        await s.updateProvider(draft);
      } else {
        await s.createProvider(draft);
      }
    } on CloudWriteException {
      if (!mounted) return;
      setState(() => _saving = false);
      showCloudFailure(
        context,
        _isEdit ? 'Modification du prestataire' : 'Création du prestataire',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  /// Confirme la suppression, puis la refuse si des réservations existent.
  Future<void> _delete() async {
    final p = widget.existing;
    if (p == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Supprimer ce prestataire ?', style: AppTypography.title),
        content: Text(
          'La fiche « ${p.name} » sera définitivement retirée du carnet. '
          'Cette action est irréversible.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SUPPRIMER',
              style: TextStyle(color: AppColors.urgent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final s = context.read<AppState>();
    setState(() => _saving = true);
    try {
      await s.deleteProvider(p.id);
    } on CloudWriteException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.what),
          backgroundColor: AppColors.urgent,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Modifier le prestataire' : 'Nouveau prestataire',
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
                      ? 'MISE À JOUR DU PARTENAIRE'
                      : 'AJOUT D\'UN PARTENAIRE',
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 8),
                const GoldDivider(width: 46),
                const SizedBox(height: 20),

                // ── Identification ──
                _section('Identification'),
                _label('Nom du prestataire'),
                TextFormField(
                  controller: _name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Hôtel, restaurant, chauffeur…',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 14),
                _label('Catégorie'),
                TextFormField(
                  controller: _category,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Hôtel 5★, Restaurant gastronomique, Jet privé…',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Catégorie requise'
                      : null,
                ),
                const SizedBox(height: 14),
                _label('Domaine de service'),
                _dropdown<ServiceDomain>(
                  value: _domain,
                  items: ServiceDomain.values,
                  labelOf: (e) => e.label,
                  onChanged: (v) => setState(() => _domain = v ?? _domain),
                ),

                // ── Localisation ──
                _section('Localisation'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Pays'),
                          TextFormField(
                            controller: _country,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Belgique',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Ville'),
                          TextFormField(
                            controller: _city,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Ville',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Contact ──
                _section('Contact'),
                _label('Personne de contact'),
                TextFormField(
                  controller: _contactName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Prénom Nom'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Contact requis' : null,
                ),
                const SizedBox(height: 14),
                _label('E-mail'),
                TextFormField(
                  controller: _contactEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'contact@fournisseur.com',
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'E-mail requis';
                    if (!t.contains('@') || !t.contains('.')) {
                      return 'E-mail invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label('Téléphone'),
                TextFormField(
                  controller: _contactPhone,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: '+32 ...'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Téléphone requis'
                      : null,
                ),

                // ── Conditions commerciales ──
                _section('Conditions commerciales'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Tarif indicatif (€)'),
                          TextFormField(
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(hintText: '0'),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Tarif requis';
                              final d = double.tryParse(t.replaceAll(',', '.'));
                              if (d == null) return 'Invalide';
                              if (d < 0) return 'Négatif impossible';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Commission (%)'),
                          TextFormField(
                            controller: _commission,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(hintText: '10'),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Commission requise';
                              final d = double.tryParse(t.replaceAll(',', '.'));
                              if (d == null) return 'Invalide';
                              // Au-delà de 100 %, la marge dépasserait le prix
                              // payé par le client : incohérence comptable.
                              if (d < 0 || d > 100) return 'Entre 0 et 100';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Niveau de confiance'),
                _stars(),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: _hasContract,
                  onChanged: (v) => setState(() => _hasContract = v),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Contrat signé',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontSize: 12.5,
                    ),
                  ),
                  activeThumbColor: AppColors.champagne,
                ),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Prestataire actif',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontSize: 12.5,
                    ),
                  ),
                  subtitle: Text(
                    'Un prestataire inactif reste visible mais n\'est plus proposé '
                    'pour de nouvelles réservations.',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                  activeThumbColor: AppColors.champagne,
                ),

                // ── Documents & notes ──
                _section('Documents & notes'),
                _label('Documents (séparés par « ; »)'),
                TextFormField(
                  controller: _documents,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Contrat 2026 ; Assurance RC ; Grille tarifaire',
                  ),
                ),
                const SizedBox(height: 14),
                _label('Notes internes'),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Conditions négociées, historique, remarques…',
                  ),
                ),

                const SizedBox(height: 26),
                GoldButton(
                  label: _isEdit ? 'Enregistrer' : 'Créer le prestataire',
                  icon: _isEdit ? Icons.check : Icons.handshake,
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
                if (_isEdit) ...[
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('SUPPRIMER CE PRESTATAIRE'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.urgent,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sélecteur d'étoiles : le niveau de confiance se choisit au toucher.
  Widget _stars() {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => setState(() => _trustLevel = i),
            icon: Icon(
              i <= _trustLevel ? Icons.star : Icons.star_border,
              size: 24,
              color: AppColors.champagne,
            ),
            tooltip: '$i / 5',
          ),
        const SizedBox(width: 6),
        Text(
          '$_trustLevel / 5',
          style: AppTypography.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.toUpperCase(),
          style: AppTypography.label.copyWith(fontSize: 10),
        ),
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
