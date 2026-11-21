import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/firebase/rest_auth_service.dart';
import '../../core/security/password_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Boîte de dialogue de changement de mot de passe, accessible à tout
/// utilisateur connecté (client VIP comme membre du personnel).
///
/// ── POURQUOI CET ÉCRAN EXISTE ─────────────────────────────────────────
/// Sans lui, un client connecté n'avait AUCUN moyen de changer son mot de
/// passe : la seule voie était de se déconnecter et de passer par « mot de
/// passe oublié », ce qui suppose de recevoir un e-mail. Un client qui
/// soupçonne une fuite de son mot de passe ne pouvait donc pas réagir
/// immédiatement depuis son espace.
///
/// ── VÉRIFICATION DU MOT DE PASSE ACTUEL ───────────────────────────────
/// Firebase permet de changer un mot de passe avec le seul jeton de session,
/// sans redemander l'ancien. On exige malgré tout l'ancien mot de passe et on
/// le vérifie réellement en tentant une connexion : sans cela, quiconque
/// accède à une session laissée ouverte pourrait verrouiller le compte de son
/// propriétaire en changeant le mot de passe.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  /// Ouvre la boîte de dialogue. Retourne `true` si le mot de passe a changé.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

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
    final email = s.currentUser?.email ?? '';
    if (email.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // 1. Vérification RÉELLE du mot de passe actuel auprès de Firebase.
    //    On ne se contente pas de le comparer à une valeur locale : le mot de
    //    passe n'est jamais stocké côté application en production.
    final check = await RestAuthService.signIn(email, _current.text);
    if (!mounted) return;
    if (!check.ok) {
      setState(() {
        _busy = false;
        _error = check.error == 'NETWORK' || check.error == 'UNKNOWN'
            ? 'Connexion au serveur impossible. Vérifiez votre connexion '
                  'internet.'
            : 'Mot de passe actuel incorrect.';
      });
      return;
    }

    // 2. Enregistrement du nouveau mot de passe.
    final changed = await s.changeOwnPassword(
      _next.text,
      currentPassword: _current.text,
    );
    if (!mounted) return;

    setState(() => _busy = false);
    if (!changed) {
      setState(() {
        _error =
            s.lastAuthError ??
            'La modification a échoué. Réessayez dans un instant.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Changer mon mot de passe', style: AppTypography.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel',
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Saisissez votre mot de passe actuel'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
                validator: (v) => PasswordPolicy.errorText(v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'Confirmer le nouveau mot de passe',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
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
              const SizedBox(height: 10),
              Text(
                'Au moins ${PasswordPolicy.minLength} caractères, avec '
                'majuscule, minuscule, chiffre et symbole.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.greyDark,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text('ANNULER', style: AppTypography.caption),
        ),
        GoldButton(
          label: _busy ? 'Enregistrement…' : 'Enregistrer',
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}

/// Ouvre la boîte de dialogue puis confirme le résultat à la personne.
Future<void> changeMyPassword(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final changed = await ChangePasswordDialog.show(context);
  if (changed != true) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Mot de passe modifié. Votre navigateur peut proposer de '
        'l\'enregistrer. En cas de perte : « Mot de passe oublié ? » sur '
        'l\'écran de connexion, ou ${AppConfig.supportEmail}.',
      ),
    ),
  );
}
