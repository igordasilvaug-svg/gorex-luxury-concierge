import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(AppState state) {
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = state.authenticate(_email.text, _password.text);
    if (user == null) {
      setState(() {
        _busy = false;
        _error = 'Identifiants invalides. Veuillez réessayer.';
      });
    } else {
      setState(() => _busy = false);
    }
  }

  void _quickFill(String email) {
    _email.text = email;
    _password.text = 'gorex2025';
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
                const Center(child: GorexBrand()),
                const SizedBox(height: 40),
                Container(
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
                        'ACCÈS SÉCURISÉ',
                        textAlign: TextAlign.center,
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Portail confidentiel réservé aux membres et à l\'équipe.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.white,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'ADRESSE E-MAIL',
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            size: 18,
                            color: AppColors.champagne,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.white,
                        ),
                        onSubmitted: (_) => _submit(state),
                        decoration: const InputDecoration(
                          labelText: 'MOT DE PASSE',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: AppColors.champagne,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 22),
                      GoldButton(
                        label: _busy ? 'Vérification...' : 'Se connecter',
                        icon: Icons.arrow_forward,
                        fullWidth: true,
                        onPressed: _busy ? null : () => _submit(state),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'COMPTES DE DÉMONSTRATION',
                  textAlign: TextAlign.center,
                  style: AppTypography.eyebrow,
                ),
                const SizedBox(height: 14),
                _demoGrid(),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'DISCRETION. ACCESS. EXCELLENCE.',
                        style: AppTypography.eyebrow.copyWith(
                          color: AppColors.greyDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gorex Group — Belgique',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.greyDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
