import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billing/vat_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Formulaire de création / édition d'un profil client VIP.
///
/// Inclut l'identification professionnelle & la facturation :
/// numéro d'entreprise (BCE) et numéro de TVA (Belgique ou étranger),
/// adresse de facturation dédiée et activation Peppol.
class ClientFormScreen extends StatefulWidget {
  /// Si non nul, on est en mode édition.
  final Client? existing;

  const ClientFormScreen({super.key, this.existing});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _language;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _assistant;
  late final TextEditingController _assistantPhone;
  late final TextEditingController _notes;
  // Facturation
  late final TextEditingController _companyNumber;
  late final TextEditingController _vatNumber;
  late final TextEditingController _billingAddress;
  late final TextEditingController _billingEmail;

  ClientCategory _category = ClientCategory.individualVip;
  ConfidentialityLevel _confidentiality = ConfidentialityLevel.elevated;
  String? _tierId;
  String? _conciergeId;
  bool _isBusiness = false;
  bool _peppolEnabled = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    final s = context.read<AppState>();
    _name = TextEditingController(text: c?.fullName ?? '');
    _company = TextEditingController(text: c?.companyName ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _language = TextEditingController(text: c?.language ?? 'Français');
    _country = TextEditingController(text: c?.country ?? 'Belgique');
    _city = TextEditingController(text: c?.city ?? '');
    _assistant = TextEditingController(text: c?.personalAssistant ?? '');
    _assistantPhone = TextEditingController(text: c?.assistantPhone ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _companyNumber = TextEditingController(text: c?.companyNumber ?? '');
    _vatNumber = TextEditingController(text: c?.vatNumber ?? '');
    _billingAddress = TextEditingController(text: c?.billingAddress ?? '');
    _billingEmail = TextEditingController(text: c?.billingEmail ?? '');

    _category = c?.category ?? ClientCategory.individualVip;
    _confidentiality = c?.confidentiality ?? ConfidentialityLevel.elevated;
    _tierId =
        c?.subscriptionTierId ??
        (s.tiers.isNotEmpty ? s.tiers.first.id : null);
    _conciergeId = c?.assignedConciergeId;
    _isBusiness = c?.isBusiness ?? false;
    _peppolEnabled = c?.peppolEnabled ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _company,
      _email,
      _phone,
      _language,
      _country,
      _city,
      _assistant,
      _assistantPhone,
      _notes,
      _companyNumber,
      _vatNumber,
      _billingAddress,
      _billingEmail,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final draft = Client(
        id: widget.existing?.id ?? '',
        code: widget.existing?.code ?? '',
        fullName: _name.text.trim(),
        companyName: _company.text.trim().isEmpty ? null : _company.text.trim(),
        category: _category,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        language: _language.text.trim(),
        country: _country.text.trim(),
        city: _city.text.trim(),
        personalAssistant:
            _assistant.text.trim().isEmpty ? null : _assistant.text.trim(),
        assistantPhone: _assistantPhone.text.trim().isEmpty
            ? null
            : _assistantPhone.text.trim(),
        confidentiality: _confidentiality,
        subscriptionTierId: _tierId!,
        assignedConciergeId: _conciergeId,
        preferredHotels: widget.existing?.preferredHotels ?? const [],
        preferredRestaurants: widget.existing?.preferredRestaurants ?? const [],
        preferredDrivers: widget.existing?.preferredDrivers ?? const [],
        travelPreferences: widget.existing?.travelPreferences ?? const [],
        dietaryPreferences: widget.existing?.dietaryPreferences ?? const [],
        interests: widget.existing?.interests ?? const [],
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        isBusiness: _isBusiness,
        companyNumber: _isBusiness && _companyNumber.text.trim().isNotEmpty
            ? VatService.normalize(_companyNumber.text)
            : null,
        vatNumber: _isBusiness && _vatNumber.text.trim().isNotEmpty
            ? VatService.normalize(_vatNumber.text)
            : null,
        billingAddress: _billingAddress.text.trim().isEmpty
            ? null
            : _billingAddress.text.trim(),
        billingEmail: _billingEmail.text.trim().isEmpty
            ? null
            : _billingEmail.text.trim(),
        peppolEnabled: _isBusiness && _peppolEnabled,
      );

      if (_isEdit) {
        await s.updateClient(draft);
        if (mounted) _snack('Profil client mis à jour.');
      } else {
        await s.createClient(draft);
        if (mounted) _snack('Profil client créé.');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Échec de l\'enregistrement : $e');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final vat = VatService.validateVat(_vatNumber.text);
    final bce = VatService.validateBelgianCompanyNumber(_companyNumber.text);
    final peppolEligible =
        _isBusiness && vat.valid && vat.isBelgian;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Modifier le client' : 'Nouveau client VIP',
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
                  _isEdit ? 'MISE À JOUR DU PROFIL' : 'CRÉATION D\'UN PROFIL CLIENT',
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 8),
                const GoldDivider(width: 46),
                const SizedBox(height: 20),

                _section('Identité'),
                _label('Nom complet'),
                TextFormField(
                  controller: _name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Prénom Nom'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 14),
                _label('Société (optionnel)'),
                TextFormField(
                  controller: _company,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Raison sociale'),
                ),
                const SizedBox(height: 14),
                _label('Catégorie'),
                _dropdown<ClientCategory>(
                  value: _category,
                  items: ClientCategory.values,
                  labelOf: (e) => e.label,
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 14),
                _label('Confidentialité'),
                _dropdown<ConfidentialityLevel>(
                  value: _confidentiality,
                  items: ConfidentialityLevel.values,
                  labelOf: (e) => e.label,
                  onChanged: (v) =>
                      setState(() => _confidentiality = v ?? _confidentiality),
                ),

                _section('Contact'),
                _label('E-mail'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'nom@exemple.com'),
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
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: '+32 ...'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Téléphone requis' : null,
                ),
                const SizedBox(height: 14),
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
                            decoration: const InputDecoration(hintText: 'Ville'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Langue'),
                TextFormField(
                  controller: _language,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Français'),
                ),
                const SizedBox(height: 14),
                _label('Assistant(e) (optionnel)'),
                TextFormField(
                  controller: _assistant,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Prénom Nom'),
                ),
                const SizedBox(height: 14),
                _label('Téléphone assistant (optionnel)'),
                TextFormField(
                  controller: _assistantPhone,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: '+32 ...'),
                ),

                _section('Abonnement & concierge'),
                _label('Abonnement'),
                _dropdown<String>(
                  value: _tierId,
                  items: s.tiers.map((t) => t.id).toList(),
                  labelOf: (id) => s.tierById(id)?.name ?? id,
                  onChanged: (v) => setState(() => _tierId = v),
                  validator: (v) => v == null ? 'Abonnement requis' : null,
                ),
                const SizedBox(height: 14),
                _label('Concierge dédié (optionnel)'),
                _dropdown<String>(
                  value: _conciergeId,
                  items: s.staffUsers.map((u) => u.id).toList(),
                  labelOf: (id) => s.userById(id)?.fullName ?? id,
                  hint: 'Non assigné',
                  onChanged: (v) => setState(() => _conciergeId = v),
                ),

                _section('Identification & facturation'),
                Text(
                  'Pour les clients professionnels / indépendants : renseignez le '
                  'numéro d\'entreprise (BCE) et le numéro de TVA. Pour les clients '
                  'étrangers, encodez leur numéro de TVA s\'ils en possèdent un.',
                  style: AppTypography.caption.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isBusiness,
                  activeThumbColor: AppColors.champagne,
                  title: Text(
                    'Client professionnel / indépendant',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.offWhite,
                    ),
                  ),
                  subtitle: Text(
                    'Facturation B2B (BCE / TVA)',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                  onChanged: (v) => setState(() => _isBusiness = v),
                ),
                if (_isBusiness) ...[
                  const SizedBox(height: 6),
                  _label('Numéro d\'entreprise (BCE)'),
                  TextFormField(
                    controller: _companyNumber,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(hintText: '0123.456.789'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_companyNumber.text.trim().isNotEmpty)
                    _validationHint(bce.valid, bce.valid
                        ? 'Numéro BCE valide'
                        : bce.message),
                  const SizedBox(height: 14),
                  _label('Numéro de TVA'),
                  TextFormField(
                    controller: _vatNumber,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(hintText: 'BE0123456789'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_vatNumber.text.trim().isNotEmpty)
                    _validationHint(
                      vat.valid,
                      vat.valid
                          ? (vat.isBelgian
                                ? 'TVA belge valide'
                                : vat.isEu
                                ? 'TVA UE valide — exonération intracommunautaire possible'
                                : 'Numéro hors UE enregistré')
                          : vat.message,
                    ),
                  const SizedBox(height: 14),
                  _label('Adresse de facturation (optionnel)'),
                  TextFormField(
                    controller: _billingAddress,
                    maxLines: 2,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Rue, code postal, ville, pays',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('E-mail de facturation (optionnel)'),
                  TextFormField(
                    controller: _billingEmail,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'compta@entreprise.be',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _peppolEnabled,
                    activeThumbColor: AppColors.champagne,
                    title: Text(
                      'Réception des factures via Peppol',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                    subtitle: Text(
                      peppolEligible
                          ? 'Client éligible — factures électroniques activées'
                          : 'Nécessite un numéro de TVA belge valide',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        color: peppolEligible
                            ? AppColors.statusConfirmed
                            : AppColors.grey,
                      ),
                    ),
                    onChanged: peppolEligible
                        ? (v) => setState(() => _peppolEnabled = v)
                        : null,
                  ),
                ],

                _section('Notes confidentielles (optionnel)'),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Informations internes...',
                  ),
                ),

                const SizedBox(height: 26),
                GoldButton(
                  label: _isEdit ? 'Enregistrer' : 'Créer le client',
                  icon: _isEdit ? Icons.check : Icons.person_add_alt,
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

  Widget _validationHint(bool ok, String? message) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 2),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          size: 12,
          color: ok ? AppColors.statusConfirmed : AppColors.urgent,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            message ?? '',
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: ok ? AppColors.statusConfirmed : AppColors.urgent,
            ),
          ),
        ),
      ],
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
      initialValue: value,
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
}
