import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billing/vat_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/company_profile.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'peppol_settings_screen.dart';

/// Paramètres société — coordonnées officielles de l'émetteur (Gorex Group).
/// Ces informations alimentent automatiquement les factures et devis
/// (numéro d'entreprise BCE, numéro de TVA, compte bancaire professionnel,
/// identifiant Peppol) afin d'éviter les erreurs de facturation.
class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _legalName;
  late TextEditingController _brandName;
  late TextEditingController _companyNumber;
  late TextEditingController _vatNumber;
  late TextEditingController _iban;
  late TextEditingController _bic;
  late TextEditingController _bankName;
  late TextEditingController _addressLine;
  late TextEditingController _postalCode;
  late TextEditingController _city;
  late TextEditingController _country;
  late TextEditingController _countryCode;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _website;
  late TextEditingController _peppolId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().company;
    _legalName = TextEditingController(text: c.legalName);
    _brandName = TextEditingController(text: c.brandName);
    _companyNumber = TextEditingController(text: c.companyNumber);
    _vatNumber = TextEditingController(text: c.vatNumber);
    _iban = TextEditingController(text: c.iban);
    _bic = TextEditingController(text: c.bic);
    _bankName = TextEditingController(text: c.bankName);
    _addressLine = TextEditingController(text: c.addressLine);
    _postalCode = TextEditingController(text: c.postalCode);
    _city = TextEditingController(text: c.city);
    _country = TextEditingController(text: c.country);
    _countryCode = TextEditingController(text: c.countryCode);
    _email = TextEditingController(text: c.email);
    _phone = TextEditingController(text: c.phone);
    _website = TextEditingController(text: c.website);
    _peppolId = TextEditingController(text: c.peppolId);
  }

  @override
  void dispose() {
    for (final c in [
      _legalName,
      _brandName,
      _companyNumber,
      _vatNumber,
      _iban,
      _bic,
      _bankName,
      _addressLine,
      _postalCode,
      _city,
      _country,
      _countryCode,
      _email,
      _phone,
      _website,
      _peppolId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Affiche automatiquement l'identifiant Peppol (schéma 0208 = Belgique)
  /// à partir du numéro d'entreprise/TVA si le champ est vide.
  void _syncPeppolFromVat() {
    final vat = VatService.validateVat(_vatNumber.text);
    if (vat.valid && vat.isBelgian) {
      final digits = (vat.normalized ?? '').replaceFirst('BE', '');
      _peppolId.text = '0208:$digits';
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = context.read<AppState>();
    try {
      final profile = CompanyProfile(
        legalName: _legalName.text.trim(),
        brandName: _brandName.text.trim(),
        companyNumber: _companyNumber.text.trim(),
        vatNumber: VatService.normalize(_vatNumber.text),
        iban: _iban.text.trim(),
        bic: _bic.text.trim(),
        bankName: _bankName.text.trim(),
        addressLine: _addressLine.text.trim(),
        postalCode: _postalCode.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
        countryCode: _countryCode.text.trim().toUpperCase(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        website: _website.text.trim(),
        peppolId: _peppolId.text.trim(),
      );
      await s.updateCompany(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordonnées société enregistrées — facturation mise à jour.'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final vat = VatService.validateVat(_vatNumber.text);
    final bce = VatService.validateBelgianCompanyNumber(_companyNumber.text);

    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres société', style: AppTypography.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ÉMETTEUR DES FACTURES', style: AppTypography.eyebrow),
                const SizedBox(height: 8),
                const GoldDivider(width: 46),
                const SizedBox(height: 10),
                Text(
                  'Ces coordonnées officielles alimentent automatiquement vos '
                  'factures et devis. Renseignez le numéro d\'entreprise (BCE), '
                  'le numéro de TVA et le compte bancaire professionnel.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 22),

                _section('Identité'),
                _field('Raison sociale', _legalName, hint: 'Gorex Group SA'),
                _field('Nom commercial', _brandName, hint: 'GOREX LUXURY CONCIERGE'),
                _field(
                  'Numéro d\'entreprise (BCE)',
                  _companyNumber,
                  hint: '0123.456.789',
                  keyboard: TextInputType.text,
                  helper: _companyNumber.text.trim().isEmpty
                      ? null
                      : (bce.valid
                            ? 'Numéro BCE valide'
                            : bce.message),
                  helperOk: bce.valid,
                  onChanged: (_) => setState(() {}),
                ),
                _field(
                  'Numéro de TVA',
                  _vatNumber,
                  hint: 'BE0123456789',
                  helper: _vatNumber.text.trim().isEmpty
                      ? null
                      : (vat.valid ? 'Numéro de TVA valide' : vat.message),
                  helperOk: vat.valid,
                  onChanged: (_) => setState(() {}),
                ),

                _section('Compte bancaire professionnel'),
                _field('IBAN', _iban, hint: 'BE00 0000 0000 0000'),
                _field('BIC / SWIFT', _bic, hint: 'GEBABEBB'),
                _field('Banque', _bankName, hint: 'Nom de la banque'),

                _section('Adresse'),
                _field('Rue & numéro', _addressLine, hint: 'Avenue Louise 000'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _field('Code postal', _postalCode, hint: '1050'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _field('Ville', _city, hint: 'Bruxelles'),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field('Pays', _country, hint: 'Belgique'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _field(
                        'Code pays',
                        _countryCode,
                        hint: 'BE',
                      ),
                    ),
                  ],
                ),

                _section('Contact'),
                _field(
                  'E-mail',
                  _email,
                  hint: 'concierge@gorex.com',
                  keyboard: TextInputType.emailAddress,
                ),
                _field(
                  'Téléphone',
                  _phone,
                  hint: '+32 2 555 01 00',
                  keyboard: TextInputType.phone,
                ),
                _field('Site web', _website, hint: 'www.gorex.be'),

                _section('Facturation électronique — Peppol'),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Identifiant Peppol de l\'émetteur (schéma 0208 pour la '
                        'Belgique). Permet la transmission électronique des '
                        'factures via le réseau Peppol.',
                        style: AppTypography.caption.copyWith(fontSize: 10.5),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _syncPeppolFromVat,
                      icon: const Icon(Icons.sync, size: 14),
                      label: const Text('Depuis TVA'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _field('Identifiant Peppol', _peppolId, hint: '0208:0123456789'),

                const SizedBox(height: 10),
                _peppolNotice(s.company),

                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PeppolSettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_outlined, size: 15),
                  label: const Text('CONFIGURER L\'ACCESS POINT PEPPOL'),
                ),

                const SizedBox(height: 20),
                GoldButton(
                  label: 'Enregistrer',
                  icon: Icons.check,
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

  Widget _peppolNotice(CompanyProfile c) {
    final eligible = VatService.validateVat(c.vatNumber).isBelgian;
    final color = eligible ? AppColors.statusConfirmed : AppColors.statusWaiting;
    return LuxuryCard(
      borderColor: color.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            eligible ? Icons.verified_outlined : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eligible
                      ? 'Émetteur éligible Peppol'
                      : 'Identifiants à compléter',
                  style: AppTypography.title.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  eligible
                      ? 'Les factures destinées aux clients professionnels belges '
                            'pourront être transmises électroniquement via Peppol.'
                      : 'Renseignez un numéro d\'entreprise (BCE) et un numéro de '
                            'TVA belges valides pour activer la facturation Peppol.',
                  style: AppTypography.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 10)),
        const SizedBox(height: 8),
        const GoldDivider(width: 30),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    String? helper,
    bool helperOk = true,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7, left: 2),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.label.copyWith(fontSize: 10),
            ),
          ),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            onChanged: onChanged,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
            decoration: InputDecoration(hintText: hint),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 2),
              child: Row(
                children: [
                  Icon(
                    helperOk ? Icons.check_circle_outline : Icons.error_outline,
                    size: 12,
                    color: helperOk ? AppColors.statusConfirmed : AppColors.urgent,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      helper,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: helperOk
                            ? AppColors.statusConfirmed
                            : AppColors.urgent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
