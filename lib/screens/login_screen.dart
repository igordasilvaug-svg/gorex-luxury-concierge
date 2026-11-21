import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../state/app_state.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import 'legal/user_guide_screen.dart';
import 'legal/legal_hub_screen.dart';
import 'about/about_screen.dart';
import 'access/client_signup_screen.dart';
import '../widgets/language_selector.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();

  /// Groupe de remplissage automatique : c'est lui qui indique au navigateur
  /// (Safari/trousseau iCloud, Chrome/Google Password Manager) que le couple
  /// identifiant + mot de passe vient d'être soumis et peut être proposé à
  /// l'enregistrement. Sans clôture explicite du contexte, aucun gestionnaire
  /// de mots de passe ne propose l'enregistrement.
  final GlobalKey<FormState> _autofillKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // Assainissement défensif : on retire les espaces parasites en début/fin
    // (fréquents après un copier-coller) qui provoquent un échec de connexion.
    final ok = await state.signInWithFirebase(
      _email.text.trim(),
      _password.text.trim(),
    );
    if (!mounted) return;

    // ── ENREGISTREMENT DU MOT DE PASSE PAR LE NAVIGATEUR ──
    // `finishAutofillContext()` signale au navigateur que la saisie est
    // terminée. Appelé uniquement en cas de SUCCÈS : c'est ce signal qui
    // déclenche, sur iOS/macOS (trousseau iCloud) comme sur Chrome
    // (Google Password Manager) ou Android, la proposition d'enregistrer
    // le couple identifiant / mot de passe. Sur échec, on ne clôture pas,
    // pour éviter de mémoriser un mot de passe erroné.
    if (ok) {
      TextInput.finishAutofillContext(shouldSave: true);
    }

    setState(() {
      _busy = false;
      if (!ok) _error = state.lastAuthError ?? state.tr('login.invalid');
    });
  }

  Future<void> _forgotPassword(AppState state) async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(
        () => _error =
            'Saisissez d\'abord votre adresse e-mail : le lien de '
            'réinitialisation y sera envoyé.',
      );
      return;
    }
    setState(() => _busy = true);
    final sent = await state.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          sent
              ? 'Lien envoyé à $email. Ouvrez-le pour choisir un nouveau mot '
                    'de passe : votre compte et vos dossiers sont conservés. '
                    'Rien reçu ? Vérifiez les indésirables, ou écrivez à '
                    '${AppConfig.supportEmail}.'
              : 'Envoi impossible pour le moment. Réessayez dans un instant, '
                    'ou écrivez à ${AppConfig.supportEmail}.',
        ),
      ),
    );
  }

  void _quickFill(String email) {
    _email.text = email;
    // Aucun mot de passe n'est pré-rempli : un mot de passe en clair écrit
    // dans le code se retrouve dans le paquet JavaScript publié, où il est
    // lisible par n'importe qui. Le raccourci ne renseigne donc que l'adresse.
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FadeSlideIn(
                  duration: Duration(milliseconds: 700),
                  child: Center(child: GorexBrand()),
                ),
                const SizedBox(height: 40),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.divider, width: 0.6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: GoldDivider(width: 44)),
                        const SizedBox(height: 20),
                        Text(
                          state.tr('login.secure_access'),
                          textAlign: TextAlign.center,
                          style: AppTypography.eyebrow,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.tr('login.subtitle'),
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 26),
                        AutofillGroup(
                          key: _autofillKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization: TextCapitalization.none,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.white,
                                ),
                                decoration: InputDecoration(
                                  labelText: state.tr('login.email'),
                                  prefixIcon: const Icon(
                                    Icons.alternate_email,
                                    size: 18,
                                    color: AppColors.champagne,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _password,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization: TextCapitalization.none,
                                autofillHints: const [AutofillHints.password],
                                // `current-password` : indique qu'il s'agit du mot de passe
                                // EXISTANT, condition pour que le gestionnaire propose
                                // l'enregistrement du couple identifiant / mot de passe.
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.white,
                                ),
                                onSubmitted: (_) => _submit(state),
                                decoration: InputDecoration(
                                  labelText: state.tr('login.password'),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: AppColors.champagne,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: AppColors.grey,
                                    ),
                                    tooltip: _obscure
                                        ? 'Afficher le mot de passe'
                                        : 'Masquer le mot de passe',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 22),
                        GoldButton(
                          label: _busy
                              ? state.tr('login.checking')
                              : state.tr('login.signin'),
                          icon: Icons.arrow_forward,
                          fullWidth: true,
                          onPressed: _busy ? null : () => _submit(state),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _forgotPassword(state),
                            child: const Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.grey,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.greyDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (AppConfig.showDemoAccounts) ...[
                  const SizedBox(height: 26),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: Text(
                      state.tr('login.demo_accounts'),
                      textAlign: TextAlign.center,
                      style: AppTypography.eyebrow,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 400),
                    child: _demoGrid(),
                  ),
                ],
                const SizedBox(height: 22),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ClientSignupScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 16,
                      color: AppColors.champagne,
                    ),
                    label: const Text(
                      'Accès client — Créer un compte',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.champagne,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 520),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'DISCRETION. ACCESS. EXCELLENCE.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                            color: AppColors.greyDark,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Gorex Group — Belgique',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.greyDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      _footLink(
                        state.tr('login.guide'),
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UserGuideScreen(),
                          ),
                        ),
                      ),
                      _footSep(),
                      _footLink(
                        state.tr('login.about'),
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                      _footSep(),
                      _footLink(
                        state.tr('login.legal'),
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalHubScreen(),
                          ),
                        ),
                      ),
                      _footSep(),
                      _footLink(
                        state.tr('login.support'),
                        () => _showSupportDialog(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 640),
                  child: Center(child: LanguageSelector(dense: true)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footLink(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.grey,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.greyDark,
        ),
      ),
    );
  }

  Widget _footSep() =>
      Container(width: 1, height: 12, color: AppColors.divider);

  /// Affiche les coordonnées d'assistance du groupe.
  ///
  /// Sert aussi à désamorcer un doute légitime : les e-mails de
  /// réinitialisation sont émis par l'infrastructure Firebase (adresse en
  /// `@gorex-concierge.firebaseapp.com`), pas depuis `@gorex-group.eu`. Un
  /// utilisateur qui ne sait pas cela peut croire à une tentative d'hameçonnage
  /// et ignorer le lien. L'écran explique l'origine réelle du message et donne
  /// l'adresse à contacter en cas de doute.
  void _showSupportDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Assistance', style: AppTypography.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                AppConfig.supportEmail,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.champagne,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Écrivez à cette adresse pour toute difficulté de connexion, '
                'perte d\'accès ou question sur votre compte.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 16),
              Text(
                'ORIGINE DES E-MAILS DE MOT DE PASSE',
                style: AppTypography.eyebrow,
              ),
              const SizedBox(height: 6),
              Text(
                'Les messages de réinitialisation sont expédiés par '
                'l\'infrastructure d\'authentification Firebase, depuis une '
                'adresse en @gorex-concierge.firebaseapp.com. Une adresse '
                'd\'expédition en @gorex-group.eu exigerait un serveur '
                'd\'envoi externe. En cas de doute sur un message reçu, ne '
                'cliquez pas et écrivez-nous à l\'adresse ci-dessus.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.greyDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('FERMER'),
          ),
        ],
      ),
    );
  }

  Widget _demoGrid() {
    final accounts = [
      ['CEO', 'ceo@gorex.com', Icons.workspace_premium_outlined],
      ['Concierge Mgr', 'manager@gorex.com', Icons.supervisor_account_outlined],
      ['Senior Concierge', 'senior@gorex.com', Icons.person_outline],
      ['Travel Manager', 'travel@gorex.com', Icons.flight_takeoff_outlined],
      ['Security', 'security@gorex.com', Icons.shield_outlined],
      ['Finance', 'finance@gorex.com', Icons.account_balance_outlined],
      ['Client VIP (PRIVATE)', 'client@gorex.com', Icons.star_outline],
      ['Client VIP (ELITE)', 'eleanor@gorex.com', Icons.star_border],
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: accounts.map((a) {
        return InkWell(
          onTap: () => _quickFill(a[1] as String),
          borderRadius: BorderRadius.circular(3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.anthracite,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.divider, width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(a[2] as IconData, size: 14, color: AppColors.champagne),
                const SizedBox(width: 8),
                Text(
                  a[0] as String,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.greyLight,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
