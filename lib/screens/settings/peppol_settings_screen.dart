import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billing/peppol_service.dart';
import '../../core/billing/vat_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/peppol_config.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Configuration de l'Access Point Peppol — facturation électronique.
///
/// Relie l'application à un Access Point Peppol agréé (API REST) afin de
/// transmettre réellement les factures UBL / Peppol BIS Billing 3.0.
class PeppolSettingsScreen extends StatefulWidget {
  const PeppolSettingsScreen({super.key});

  @override
  State<PeppolSettingsScreen> createState() => _PeppolSettingsScreenState();
}

class _PeppolSettingsScreenState extends State<PeppolSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseUrl;
  late TextEditingController _apiKey;
  late TextEditingController _senderPeppolId;
  late TextEditingController _legalEntityId;
  late TextEditingController _scheme;
  late TextEditingController _timeout;
  late TextEditingController _webhookUrl;
  bool _enabled = false;
  bool _autoRefresh = false;
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().peppol;
    _baseUrl = TextEditingController(text: c.apiBaseUrl);
    _apiKey = TextEditingController(text: c.apiKey);
    _senderPeppolId = TextEditingController(text: c.senderPeppolId);
    _legalEntityId = TextEditingController(text: c.senderLegalEntityId);
    _scheme = TextEditingController(text: c.defaultScheme);
    _timeout = TextEditingController(text: c.timeoutSeconds.toString());
    _webhookUrl = TextEditingController(text: c.webhookUrl);
    _enabled = c.enabled;
    _autoRefresh = c.autoRefresh;
  }

  @override
  void dispose() {
    for (final c in [
      _baseUrl,
      _apiKey,
      _senderPeppolId,
      _legalEntityId,
      _scheme,
      _timeout,
      _webhookUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  PeppolConfig _collect() => PeppolConfig(
    enabled: _enabled,
    apiBaseUrl: _baseUrl.text.trim(),
    apiKey: _apiKey.text.trim(),
    senderPeppolId: _senderPeppolId.text.trim(),
    senderLegalEntityId: _legalEntityId.text.trim(),
    defaultScheme: _scheme.text.trim().isEmpty ? '0208' : _scheme.text.trim(),
    timeoutSeconds: int.tryParse(_timeout.text.trim()) ?? 30,
    webhookUrl: _webhookUrl.text.trim(),
    autoRefresh: _autoRefresh,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().updatePeppol(_collect());
      if (mounted) {
        _snack('Configuration Peppol enregistrée.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Échec : $e');
      }
    }
  }

  Future<void> _test() async {
    // ── TESTER N'ENREGISTRE PAS ─────────────────────────────────────────
    // Cette méthode appelait `updatePeppol(_collect())` avant de tester :
    // une clé FAUSSE était donc enregistrée en base (et dans le document
    // secret) avant même de savoir si elle fonctionne. Le test porte
    // désormais sur la saisie en cours, sans rien persister : on n'enregistre
    // que ce qui a été validé, et seulement via le bouton « Enregistrer ».
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    final res = await PeppolService.testConnection(_collect());
    if (!mounted) return;
    setState(() => _testing = false);
    _snack(
      res.success
          ? '${res.message} (configuration non enregistrée)'
          : res.message,
      ok: res.success,
    );
  }

  void _syncFromCompany() {
    final s = context.read<AppState>();
    final vat = VatService.validateVat(s.company.vatNumber);
    if (vat.valid && vat.isBelgian) {
      final digits = (vat.normalized ?? '').replaceFirst('BE', '');
      _senderPeppolId.text = '0208:$digits';
      setState(() {});
    }
  }

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? null : AppColors.urgent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Access Point Peppol', style: AppTypography.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('FACTURATION ÉLECTRONIQUE', style: AppTypography.eyebrow),
                const SizedBox(height: 8),
                const GoldDivider(width: 46),
                const SizedBox(height: 10),
                Text(
                  'Reliez l\'application à un Access Point Peppol agréé '
                  '(Storecove, Tickstar, Unifiedpost…) pour transmettre '
                  'réellement vos factures au format UBL / Peppol BIS '
                  'Billing 3.0. Sans configuration, aucune facture n\'est '
                  'transmise : seul le document UBL est généré localement.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 18),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  activeThumbColor: AppColors.champagne,
                  title: Text(
                    'Activer la transmission réelle',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.offWhite,
                    ),
                  ),
                  subtitle: Text(
                    _enabled
                        ? 'Les factures seront transmises via l\'Access Point.'
                        : 'Aucune transmission (l\'access point est désactivé).',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                  onChanged: (v) => setState(() => _enabled = v),
                ),

                _statusCard(s),

                const SizedBox(height: 8),
                _section('API de l\'Access Point'),
                _field(
                  'URL de base de l\'API',
                  _baseUrl,
                  hint: 'https://api.storecove.com/api/v2',
                  keyboard: TextInputType.url,
                ),
                _label('Clé d\'API (Bearer)'),
                TextFormField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••••••••••',
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
                  validator: (v) => _enabled && (v == null || v.trim().isEmpty)
                      ? 'Clé d\'API requise'
                      : null,
                ),
                const SizedBox(height: 14),

                _section('Identité de l\'émetteur'),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Identifiant Peppol de l\'émetteur chez l\'Access Point.',
                        style: AppTypography.caption.copyWith(fontSize: 10.5),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _syncFromCompany,
                      icon: const Icon(Icons.sync, size: 14),
                      label: const Text('Depuis société'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _field(
                  'Identifiant Peppol émetteur',
                  _senderPeppolId,
                  hint: '0208:0123456749',
                ),
                _field(
                  'ID entité légale (Access Point)',
                  _legalEntityId,
                  hint: 'ex. 1',
                  keyboard: TextInputType.number,
                  // L'API de l'Access Point attend un ENTIER. Une valeur non
                  // numérique faisait auparavant transmettre la facture sous
                  // l'entité n°1 (repli silencieux) : on bloque à la saisie.
                  numeric: true,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _field(
                        'Schéma destinataire',
                        _scheme,
                        hint: '0208',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _field(
                        'Délai (secondes)',
                        _timeout,
                        hint: '30',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                _section('Suivi de statut'),
                _field(
                  'URL de webhook (notifications)',
                  _webhookUrl,
                  hint: 'https://votre-domaine/gorex/peppol-webhook',
                  keyboard: TextInputType.url,
                ),
                // ── AVERTISSEMENT HONNÊTE ──────────────────────────────
                // L'application sait TRAITER une notification
                // (`AppState.ingestPeppolWebhook`), mais aucun serveur ne
                // l'écoute : le site est un Worker Cloudflare qui ne sert que
                // des fichiers statiques et refuse les requêtes POST (405).
                // Déclarer une URL ici ne produirait donc aucune réception.
                // Il faut un point d'entrée serveur (Cloud Functions) pour
                // cela, non déployé à ce jour.
                Text(
                  'Réception NON active : l\'application sait traiter une '
                  'notification de statut, mais aucun serveur n\'écoute encore '
                  'cette URL — le site ne répond qu\'en lecture. Déclarer une '
                  'adresse ici ne produira donc aucune mise à jour automatique. '
                  'En attendant, utilisez le rafraîchissement manuel depuis '
                  'l\'écran Finance (bouton « Rafraîchir le statut »).',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10.5,
                    color: AppColors.statusWaiting,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoRefresh,
                  activeThumbColor: AppColors.champagne,
                  title: Text(
                    'Rafraîchissement automatique',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.offWhite,
                    ),
                  ),
                  subtitle: Text(
                    'Interroge l\'Access Point au chargement de l\'écran Finance.',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                  onChanged: (v) => setState(() => _autoRefresh = v),
                ),

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 15),
                  label: Text(
                    _testing ? 'TEST EN COURS...' : 'TESTER LA CONNEXION',
                  ),
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

  Widget _statusCard(AppState s) {
    final configured = s.peppol.isConfigured;
    final color = configured
        ? AppColors.statusConfirmed
        : AppColors.statusWaiting;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: LuxuryCard(
        borderColor: color.withValues(alpha: 0.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              configured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    configured
                        ? 'Access Point configuré'
                        : 'Access Point non configuré',
                    style: AppTypography.title.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    configured
                        ? 'Les factures éligibles seront transmises réellement.'
                        : 'Aucune transmission n\'a lieu. Les factures restent '
                              '« Prêt à envoyer » et le document UBL est '
                              'seulement généré localement.',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.toUpperCase(),
          style: AppTypography.label.copyWith(fontSize: 10),
        ),
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
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
            decoration: InputDecoration(hintText: hint),
            validator: (v) {
              if (!_enabled) return null;
              if (label.contains('URL') && (v == null || v.trim().isEmpty)) {
                return 'URL requise';
              }
              if (label.contains('Peppol') && (v == null || v.trim().isEmpty)) {
                return 'Identifiant requis';
              }
              if (numeric) {
                final t = (v ?? '').trim();
                // Obligatoire dès que la transmission est activée : sans lui
                // l'envoi est refusé (l'API exige un entier). Mieux vaut le
                // dire ici que de laisser l'utilisateur découvrir l'échec au
                // moment de transmettre une facture réelle.
                if (t.isEmpty) return 'Identifiant requis';
                if (int.tryParse(t) == null) return 'Nombre entier attendu';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 7, left: 2),
    child: Text(
      t.toUpperCase(),
      style: AppTypography.label.copyWith(fontSize: 10),
    ),
  );
}
