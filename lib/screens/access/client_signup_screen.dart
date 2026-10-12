import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_auth_service.dart';
import '../../core/firebase/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Inscription d'un nouveau client (e-mail / mot de passe réels Firebase).
///
/// Renseigne les données personnelles et professionnelles, crée le compte
/// Firebase Auth, envoie la vérification d'e-mail, puis crée la fiche client
/// (Firestore si disponible, sinon état local).
class ClientSignupScreen extends StatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  State<ClientSignupScreen> createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends State<ClientSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _country = TextEditingController(text: 'Belgique');
  final _company = TextEditingController();
  final _position = TextEditingController();
  final _companyNumber = TextEditingController();
  final _vatNumber = TextEditingController();
  final _companyCountry = TextEditingController(text: 'Belgique');
  final _billingAddress = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String _language = 'fr';
  bool _isBusiness = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _fullName, _email, _phone, _address, _country, _company, _position,
      _companyNumber, _vatNumber, _companyCountry, _billingAddress,
      _password, _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _email.text.trim().toLowerCase();

    // 1. Création du compte Firebase (e-mail / mot de passe + vérification).
    final res = await FirebaseAuthService.signUp(email, _password.text);
    if (!res.ok) {
      setState(() {
        _busy = false;
        _error = _signupError(res.error);
      });
      return;
    }

    // 2. Fiche client (Firestore si dispo, sinon local).
    final draft = Client(
      id: '',
      code: '',
      fullName: _fullName.text.trim(),
      companyName: _isBusiness && _company.text.trim().isNotEmpty
          ? _company.text.trim()
          : null,
      category: _isBusiness ? ClientCategory.corporate : ClientCategory.individualVip,
      email: email,
      phone: _phone.text.trim(),
      language: _languageLabel(_language),
      country: _country.text.trim(),
      city: _address.text.trim(),
      subscriptionTierId: state.tiers.isNotEmpty ? state.tiers.first.id : '',
      isBusiness: _isBusiness,
      companyNumber: _companyNumber.text.trim().isEmpty
          ? null
          : _companyNumber.text.trim(),
      vatNumber:
          _vatNumber.text.trim().isEmpty ? null : _vatNumber.text.trim(),
      billingAddress: _billingAddress.text.trim().isEmpty
          ? null
          : _billingAddress.text.trim(),
      billingEmail: email,
      createdAt: DateTime.now(),
    );
    final client = await state.createClient(draft);

    // 2b. Persistance de la fiche client dans Firestore (si disponible).
    try {
      await FirestoreService.updateDocument('clients', client.id, client.toMap());
    } catch (_) {}

    // 2c. Profil d'identité (uid → clientId) pour l'isolation des données.
    if (res.uid != null) {
      try {
        await FirestoreService.updateDocument('user_profiles', res.uid!, {
          'uid': res.uid,
          'email': email,
          'role': 'vipClient',
          'clientId': client.id,
        });
      } catch (_) {}
    }

    // 3. Compte applicatif lié au client.
    await state.createUser(
      fullName: _fullName.text.trim(),
      email: email,
      password: '', // géré par Firebase Auth, jamais stocké en clair
      role: UserRole.vipClient,
      phone: _phone.text.trim(),
      clientId: client.id,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Compte créé. Un e-mail de vérification a été envoyé à $email.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  String _signupError(String? code) {
    switch (code) {
      case 'EMAIL_EXISTS':
        return 'Cette adresse e-mail est déjà utilisée.';
      case 'INVALID_EMAIL':
        return 'Adresse e-mail invalide.';
      case 'WEAK_PASSWORD':
        return 'Mot de passe trop faible (8 caractères minimum).';
      case 'OPERATION_NOT_ALLOWED':
        return 'L\'inscription est momentanément indisponible.';
      default:
        return 'Inscription impossible : ${code ?? 'erreur inconnue'}.';
    }
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'nl':
        return 'Néerlandais';
      case 'en':
        return 'Anglais';
      default:
        return 'Français';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte client')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: GorexBrand()),
                  const SizedBox(height: 18),
                  Text('ACCÈS CLIENT', style: AppTypography.eyebrow,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),

                  // ── Données personnelles ──
                  const SectionLabel('DONNÉES PERSONNELLES'),
                  _field(_fullName, 'Nom et prénom', required: true),
                  _field(_email, 'Adresse e-mail',
                      required: true, keyboard: TextInputType.emailAddress),
                  _field(_phone, 'Téléphone', required: true,
                      keyboard: TextInputType.phone),
                  _field(_address, 'Adresse', required: true),
                  _field(_country, 'Pays', required: true),
                  const SizedBox(height: 8),
                  _languageSelector(),
                  const SizedBox(height: 16),

                  // ── Données professionnelles ──
                  Row(
                    children: [
                      Text('Données professionnelles',
                          style: AppTypography.bodyMedium),
                      const Spacer(),
                      Switch(
                        value: _isBusiness,
                        activeThumbColor: AppColors.champagne,
                        onChanged: (v) => setState(() => _isBusiness = v),
                      ),
                    ],
                  ),
                  if (_isBusiness) ...[
                    _field(_company, 'Nom de l\'entreprise'),
                    _field(_position, 'Fonction'),
                    _field(_companyNumber, 'N° d\'entreprise (BCE)'),
                    _field(_vatNumber, 'N° de TVA'),
                    _field(_companyCountry, 'Pays d\'immatriculation'),
                    _field(_billingAddress, 'Adresse de facturation'),
                  ],
                  const SizedBox(height: 16),

                  // ── Mot de passe ──
                  const SectionLabel('SÉCURITÉ'),
                  _field(_password, 'Mot de passe (8 caractères min.)',
                      required: true, obscure: true),
                  _field(_confirm, 'Confirmer le mot de passe',
                      required: true, obscure: true),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  GoldButton(
                    label: _busy ? 'Création…' : 'Créer mon compte',
                    icon: Icons.person_add_alt_1_outlined,
                    fullWidth: true,
                    onPressed: _busy ? null : () => _submit(state),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) {
            return 'Champ obligatoire';
          }
          if (obscure && v != null && v.isNotEmpty && v.length < 8) {
            return '8 caractères minimum';
          }
          if (label == 'Confirmer le mot de passe' && v != _password.text) {
            return 'Les mots de passe ne correspondent pas';
          }
          if (label == 'Adresse e-mail' && v != null && v.isNotEmpty &&
              !v.contains('@')) {
            return 'Adresse e-mail invalide';
          }
          return null;
        },
      ),
    );
  }

  Widget _languageSelector() {
    return Row(
      children: [
        Text('Langue préférée : ', style: AppTypography.caption),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _language,
          dropdownColor: AppColors.surface,
          style: AppTypography.caption.copyWith(color: AppColors.white),
          items: const [
            DropdownMenuItem(value: 'fr', child: Text('Français')),
            DropdownMenuItem(value: 'nl', child: Text('Néerlandais')),
            DropdownMenuItem(value: 'en', child: Text('Anglais')),
          ],
          onChanged: (v) => setState(() => _language = v ?? 'fr'),
        ),
      ],
    );
  }
}
