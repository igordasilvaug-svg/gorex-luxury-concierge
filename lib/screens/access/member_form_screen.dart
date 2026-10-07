import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Formulaire de création / édition d'un accès (personnel ou client VIP)
class MemberFormScreen extends StatefulWidget {
  /// Si non nul, on est en mode édition
  final AppUser? existing;

  /// Pré-sélectionne un client VIP (création d'accès client depuis sa fiche)
  final String? clientId;

  const MemberFormScreen({super.key, this.existing, this.clientId});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _title;
  late final TextEditingController _phone;
  UserRole _role = UserRole.concierge;
  String? _clientId;
  bool _obscure = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _name = TextEditingController(text: u?.fullName ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _password = TextEditingController(text: u?.password ?? '');
    _title = TextEditingController(text: u?.title ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _role = u?.role ?? (widget.clientId != null ? UserRole.vipClient : UserRole.concierge);
    _clientId = u?.clientId ?? widget.clientId;
    if (!_isEdit) _password.text = _generatePassword();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _title.dispose();
    _phone.dispose();
    super.dispose();
  }

  static String _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s = context.read<AppState>();
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (s.emailExists(email, exceptId: widget.existing?.id)) {
      _snack('Cet e-mail est déjà utilisé par un autre accès.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          fullName: name,
          email: email,
          password: password,
          role: _role,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          clientId: _role == UserRole.vipClient ? _clientId : null,
        );
        await s.updateUser(updated);
        if (mounted) _snack('Accès mis à jour.');
      } else {
        await s.createUser(
          fullName: name,
          email: email,
          password: password,
          role: _role,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          clientId: _role == UserRole.vipClient ? _clientId : null,
        );
        if (mounted) _snack('Accès créé — identifiants à transmettre.');
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
    final clients = s.clients;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Modifier un accès' : 'Nouvel accès',
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
                      ? 'MISE À JOUR DU COMPTE'
                      : 'CRÉATION D\'UN COMPTE PERSONNEL',
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 8),
                const GoldDivider(width: 46),
                const SizedBox(height: 20),

                _label('Nom complet'),
                TextFormField(
                  controller: _name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Prénom Nom',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 16),

                _label('Adresse e-mail professionnelle'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'prenom.nom@gorex.com',
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      size: 18,
                      color: AppColors.grey,
                    ),
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
                const SizedBox(height: 16),

                _label('Rôle & permissions'),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  dropdownColor: AppColors.surfaceElevated,
                  iconEnabledColor: AppColors.champagne,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                  items: UserRole.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            '${r.label}  ·  ${r.department}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: 16),

                if (_role == UserRole.vipClient) ...[
                  _label('Rattacher à un profil client VIP'),
                  DropdownButtonFormField<String>(
                    initialValue: _clientId,
                    dropdownColor: AppColors.surfaceElevated,
                    iconEnabledColor: AppColors.champagne,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Sélectionner un client',
                      prefixIcon: Icon(
                        Icons.link,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ),
                    items: clients
                        .map(
                          (Client c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.fullName} · ${c.code}',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _clientId = v),
                    validator: (v) => v == null
                        ? 'Sélectionnez le profil client associé'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                _label('Fonction / intitulé (optionnel)'),
                TextFormField(
                  controller: _title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'ex. Senior Concierge — Bruxelles',
                    prefixIcon: Icon(
                      Icons.work_outline,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _label('Téléphone (optionnel)'),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: '+32 ...',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _label('Mot de passe temporaire'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.grey,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: AppColors.grey,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? '6 caractères minimum' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Le collaborateur devra changer ce mot de passe à sa première connexion.',
                        style: AppTypography.caption.copyWith(fontSize: 10.5),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _password.text = _generatePassword(),
                      ),
                      icon: const Icon(Icons.autorenew, size: 14),
                      label: const Text('Générer'),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                GoldButton(
                  label: _isEdit ? 'Enregistrer' : 'Créer l\'accès',
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

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 7, left: 2),
    child: Text(t.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 10)),
  );
}
