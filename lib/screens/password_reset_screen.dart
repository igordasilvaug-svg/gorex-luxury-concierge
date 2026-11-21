import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/firebase/rest_auth_service.dart';
import '../core/security/password_policy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Réinitialisation du mot de passe à partir du lien reçu par e-mail.
///
/// ── CE QUE FAIT CET ÉCRAN ───────────────────────────────────────────────
/// Firebase envoie un lien contenant un code à usage unique (`oobCode`).
/// Ce code est vérifié ici AVANT toute saisie, puis échangé contre un nouveau
/// mot de passe directement auprès de Firebase.
///
/// ── POURQUOI DANS L'APPLICATION ET NON SUR LA PAGE GOOGLE ───────────────
/// La page générique de Firebase n'applique aucune règle de robustesse. En
/// terminant la procédure ici, la règle maison [PasswordPolicy] (12 caractères,
/// majuscule, minuscule, chiffre, symbole, pas de mot familier) est appliquée.
///
/// ── LE COMPTE EST CONSERVÉ ──────────────────────────────────────────────
/// Seule l'empreinte du mot de passe change : l'identifiant `uid`, le rôle, les
/// dossiers, l'historique et le journal d'audit restent attachés au même
/// compte. Rien n'est supprimé, rien n'est recréé.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.oobCode, this.onFinished});

  /// Code à usage unique transmis par Firebase dans l'URL.
  final String oobCode;

  /// Appelé lorsque la personne quitte l'écran (retour à la connexion ou
  /// session ouverte). Permet à la racine de l'application de reprendre la
  /// main sans rechargement de page.
  final VoidCallback? onFinished;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

enum _Step { verifying, invalid, form, done }

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.verifying;
  String? _accountEmail;
  String? _error;
  bool _obscure = true;
  bool _saving = false;

  /// Vrai si le code vient d'être consommé par une réinitialisation réussie :
  /// dans ce cas un lien « déjà utilisé » est le comportement NORMAL (rechargement
  /// de page) et non une erreur à signaler.
  bool _alreadyDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Vérifie le code auprès de Firebase avant de proposer une saisie.
  Future<void> _verify() async {
    final check = await RestAuthService.verifyResetCode(widget.oobCode);
    if (!mounted) return;
    final state = context.read<AppState>();
    // Lecture puis effacement : le drapeau ne vaut que pour cette ouverture.
    final dejaTente = state.resetAttempted;
    state.consumeResetAttempt();
    setState(() {
      if (check.ok) {
        _accountEmail = check.email;
        _step = _Step.form;
      } else {
        _step = _Step.invalid;
        _alreadyDone = dejaTente;
        _error = check.error == 'NETWORK'
            ? 'Connexion au serveur impossible. Vérifiez votre connexion '
                  'internet puis rouvrez le lien.'
            : null; // message générique « lien inutilisable » à l'écran
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await state.signInAfterPasswordReset(
      widget.oobCode,
      _password.text,
    );
    if (!mounted) return;

    if (ok == null) {
      setState(() {
        _saving = false;
        _error =
            'Connexion au serveur impossible. Votre mot de passe n\'a pas été '
            'modifié. Réessayez dans un instant.';
      });
      return;
    }

    if (ok == false) {
      setState(() {
        _saving = false;
        _error = state.lastAuthError ?? 'La réinitialisation a échoué.';
      });
      return;
    }

    // Succès : la session est ouverte. On le signale, puis l'application prend
    // le relais d'elle-même (l'état courant n'est plus « déconnecté »).
    setState(() {
      _saving = false;
      _step = _Step.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(child: GorexBrand(compact: true)),
                const SizedBox(height: 28),
                const GoldDivider(width: 46),
                const SizedBox(height: 22),
                _header(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.divider, width: 0.6),
                  ),
                  child: _body(),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => _goToLogin(context),
                    child: const Text('RETOUR À LA CONNEXION'),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Assistance : ${AppConfig.supportEmail}',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.greyDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final (eyebrow, title) = switch (_step) {
      _Step.verifying => ('SÉCURITÉ DU COMPTE', 'Vérification du lien'),
      _Step.invalid => ('Lien inutilisable', 'Réinitialisation'),
      _Step.form => ('SÉCURITÉ DU COMPTE', 'Nouveau mot de passe'),
      _Step.done => ('Compte sécurisé', 'Mot de passe modifié'),
    };
    return Column(
      children: [
        Text(eyebrow, style: AppTypography.eyebrow, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(title, style: AppTypography.headline, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.verifying:
        return const Column(
          children: [
            SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 18),
            Text(
              'Vérification de votre lien…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        );

      case _Step.invalid:
        if (_alreadyDone) {
          // Rechargement de page après une réinitialisation réussie : le code
          // a bien été consommé, ce n'est pas un échec.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                'Ce lien a déjà été utilisé pour définir un nouveau mot de '
                'passe.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Connectez-vous avec le mot de passe que vous venez de '
                'choisir. Si vous ne vous en souvenez plus, demandez un '
                'nouveau lien : votre compte reste intact.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              GoldButton(
                label: 'Aller à la connexion',
                icon: Icons.login,
                fullWidth: true,
                onPressed: () => _goToLogin(context),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              ErrorBanner(message: _error!)
            else
              Text(
                'Ce lien de réinitialisation n\'est plus valable : il a expiré '
                '(validité 1 heure) ou il a déjà servi.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 18),
            Text(
              'Votre compte et vos données sont intacts. Demandez simplement '
              'un nouveau lien depuis l\'écran de connexion.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            GoldButton(
              label: 'Demander un nouveau lien',
              icon: Icons.refresh,
              fullWidth: true,
              onPressed: () => _goToLogin(context),
            ),
          ],
        );

      case _Step.form:
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_accountEmail != null) ...[
                Text(
                  'Compte : $_accountEmail',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagne,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                'Choisissez un mot de passe personnel. Votre compte reste le '
                'même : dossiers, historique et rôle sont conservés.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Au moins ${PasswordPolicy.minLength} caractères, avec '
                'majuscule, minuscule, chiffre et symbole.',
                style: AppTypography.caption.copyWith(color: AppColors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.grey,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
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
                validator: (v) => PasswordPolicy.errorText(v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.grey,
                  ),
                ),
                validator: (v) => v != _password.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              GoldButton(
                label: _saving
                    ? 'Enregistrement…'
                    : 'Définir mon mot de passe',
                icon: Icons.shield_outlined,
                fullWidth: true,
                onPressed: _saving ? null : _submit,
              ),
              const SizedBox(height: 12),
              Text(
                'Ce lien ne peut servir qu\'une seule fois.',
                style: AppTypography.caption.copyWith(color: AppColors.greyDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case _Step.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'Votre nouveau mot de passe est actif et votre session est '
              'ouverte.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Votre navigateur peut maintenant proposer de l\'enregistrer.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            GoldButton(
              label: 'Accéder à mon espace',
              icon: Icons.arrow_forward,
              fullWidth: true,
              onPressed: () => _goToLogin(context),
            ),
          ],
        );
    }
  }

  /// Quitte l'écran de réinitialisation.
  ///
  /// Un lien déjà utilisé ne doit pas rester actif : la racine de l'application
  /// reprend la main et affiche soit l'espace ouvert (session établie), soit
  /// l'écran de connexion.
  void _goToLogin(BuildContext context) {
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((r) => r.isFirst);
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}
