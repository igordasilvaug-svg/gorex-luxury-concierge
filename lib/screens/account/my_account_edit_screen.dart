import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Édition des informations personnelles du compte connecté.
///
/// Utilisé aussi bien par un client que par un membre du personnel.
/// Les modifications sont écrites dans Firestore (voir [AppState.saveMyProfile])
/// afin d'être retrouvées depuis n'importe quel appareil.
class MyAccountEditScreen extends StatefulWidget {
  const MyAccountEditScreen({super.key, this.embedded = false});

  /// `true` lorsque l'écran est affiché comme onglet de l'application
  /// (pas de route à fermer après l'enregistrement).
  final bool embedded;

  @override
  State<MyAccountEditScreen> createState() => _MyAccountEditScreenState();
}

class _MyAccountEditScreenState extends State<MyAccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final me = context.read<AppState>().currentUser;
    _fullName = TextEditingController(text: me?.fullName ?? '');
    _phone = TextEditingController(text: me?.phone ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(AppState s) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await s.saveMyProfile(fullName: _fullName.text, phone: _phone.text);
      if (!mounted) return;
      if (widget.embedded) {
        // Affiché comme onglet : on confirme sur place.
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informations enregistrées sur le serveur. '
              'Vous les retrouverez à votre prochaine connexion.',
            ),
          ),
        );
        return;
      }
      Navigator.of(context).pop(true);
    } on CloudWriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Enregistrement impossible : ${e.what.toLowerCase()}. '
            'Vos modifications n\'ont pas été conservées sur le serveur. '
            'Vérifiez votre connexion puis réessayez.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Enregistrement impossible. Réessayez dans un instant.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.currentUser;

    final content = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: GoldDivider(width: 44)),
              const SizedBox(height: 20),
              Text(
                'Ces informations sont enregistrées sur le serveur GOREX. '
                'Elles vous suivent d\'un appareil à l\'autre.',
                style: AppTypography.caption.copyWith(color: AppColors.grey),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.champagne,
                  ),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 2) return 'Indiquez votre nom complet.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '+32 ...',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppColors.champagne,
                  ),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null; // facultatif
                  if (t.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
                    return 'Numéro de téléphone invalide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // L'adresse e-mail est l'identifiant de connexion : elle n'est
              // pas modifiable ici, cela exige une procédure de vérification.
              IgnorePointer(
                child: TextFormField(
                  initialValue: me?.email ?? '',
                  enabled: false,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.grey,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail (identifiant)',
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      size: 18,
                      color: AppColors.greyDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'L\'adresse e-mail sert d\'identifiant de connexion et ne '
                'peut pas être modifiée ici.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.greyDark,
                  fontSize: 10.5,
                ),
              ),
              if (!AppConfig.isProduction) ...[
                const SizedBox(height: 12),
                Text(
                  'Mode développement : les modifications restent locales.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.statusWaiting,
                    fontSize: 10.5,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 18),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              GoldButton(
                label: _busy ? 'ENREGISTREMENT…' : 'ENREGISTRER',
                icon: Icons.check,
                fullWidth: true,
                onPressed: _busy ? null : () => _save(s),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: Text('Mes informations', style: AppTypography.title),
      ),
      body: content,
    );
  }
}
