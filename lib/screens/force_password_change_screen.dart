import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/security/password_policy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Affiché à la première connexion (ou après réinitialisation) :
/// l'utilisateur doit définir un nouveau mot de passe personnel.
class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final s = context.read<AppState>();
    setState(() => _saving = true);
    final ok = await s.changeOwnPassword(_next.text, currentPassword: _current.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe mis à jour avec succès.')),
      );
    } else {
      // Sans ce retour, un refus de Firebase (mot de passe temporaire erroné,
      // jeton expiré) laissait la personne devant un formulaire inchangé.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.lastAuthError ??
                'Le mot de passe n\'a pas pu être modifié. '
                    'Vérifiez le mot de passe temporaire.',
          ),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.currentUser;

    // Deux motifs possibles : première connexion, ou mot de passe trop faible
    // détecté à la connexion (défini via la page générique de Firebase, qui
    // n'impose aucune longueur minimale). Le message doit dire lequel.
    final weak = s.mustChangeReason == 'weak-password';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: GorexBrand()),
                  const SizedBox(height: 30),
                  const GoldDivider(width: 46),
                  const SizedBox(height: 20),
                  Text(
                    'SÉCURITÉ DU COMPTE',
                    style: AppTypography.eyebrow,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weak ? 'Mot de passe à renforcer' : 'Première connexion',
                    style: AppTypography.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weak
                        ? 'Bonjour ${user?.fullName ?? ''}, votre mot de passe '
                              'actuel ne respecte pas la règle de sécurité de '
                              'la plateforme. Votre compte et vos dossiers '
                              'sont conservés : seul le mot de passe change.'
                        : 'Bonjour ${user?.fullName ?? ''}, pour des raisons de '
                              'confidentialité, vous devez définir un nouveau '
                              'mot de passe avant d\'accéder à la plateforme.',
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),
                  TextFormField(
                    controller: _current,
                    obscureText: _obscure,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe temporaire',
                      prefixIcon: Icon(
                        Icons.lock_clock,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Saisissez le mot de passe reçu';
                      }
                      if (user != null &&
                          user.password.isNotEmpty &&
                          v != user.password) {
                        return 'Mot de passe incorrect';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _next,
                    obscureText: _obscure,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.grey,
                      ),
                    ),
                    validator: (v) => PasswordPolicy.errorText(v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(
                        Icons.check_circle_outline,
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
                    validator: (v) => v != _next.text
                        ? 'Les mots de passe ne correspondent pas'
                        : null,
                  ),
                  const SizedBox(height: 26),
                  GoldButton(
                    label: 'Définir mon mot de passe',
                    icon: Icons.shield_outlined,
                    fullWidth: true,
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _saving ? null : () => s.logout(),
                    child: const Text('SE DÉCONNECTER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
