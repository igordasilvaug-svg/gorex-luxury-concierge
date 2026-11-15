import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/billing/file_export.dart';
import '../../core/billing/sepa_pain008_generator.dart';
import '../../core/billing/sepa_validator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/client.dart';
import '../../models/sepa_mandate.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Écran de domiciliation SEPA : mandats + ordres de prélèvement.
///
/// ⚠️ Cet écran ne transmet RIEN à la banque. Il produit le fichier
/// `pain.008.001.02` que la direction dépose ensuite sur son e-banking
/// (ou transmet à son comptable). Aucune connexion bancaire automatisée
/// n'existe : le prétendre serait un mensonge sur l'état du produit.
class SepaDirectDebitScreen extends StatefulWidget {
  const SepaDirectDebitScreen({super.key});

  @override
  State<SepaDirectDebitScreen> createState() => _SepaDirectDebitScreenState();
}

class _SepaDirectDebitScreenState extends State<SepaDirectDebitScreen> {
  final _eur = NumberFormat.currency(
    locale: 'fr_BE',
    symbol: '€',
    decimalDigits: 2,
  );
  final _df = DateFormat('dd/MM/yyyy', 'fr_BE');

  SepaBatchResult? _lastBatch;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final summary = s.sepaSummary();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Domiciliation SEPA', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Text(
              'Mandats de prélèvement et ordres de recouvrement des abonnements',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 18),

            _notice(),
            const SizedBox(height: 18),

            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 980
                    ? 4
                    : (c.maxWidth > 640 ? 2 : 1);
                final w = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: w,
                      child: KpiTile(
                        label: 'Mandats actifs',
                        value: '${summary['mandatsActifs']}',
                        icon: Icons.assignment_turned_in_outlined,
                        accent: AppColors.champagne,
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: KpiTile(
                        label: 'Clients domiciliés',
                        value: '${summary['clientsEligibles']}',
                        icon: Icons.check_circle_outline,
                        accent: AppColors.success,
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: KpiTile(
                        label: 'Sans mandat',
                        value: '${summary['clientsSansMandat']}',
                        icon: Icons.warning_amber_outlined,
                        accent: summary['clientsSansMandat'] == 0
                            ? AppColors.grey
                            : AppColors.urgent,
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: KpiTile(
                        label: 'En attente',
                        value: _eur.format(summary['montantEnAttente']),
                        icon: Icons.schedule_outlined,
                        accent: AppColors.champagne,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: SectionLabel('Mandats de domiciliation'),
                ),
                if (s.can('finance'))
                  GoldButton(
                    label: 'Enregistrer un mandat',
                    icon: Icons.add_circle_outline,
                    outlined: true,
                    onPressed: () => _addMandateDialog(s),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _mandatesSection(s),

            const SizedBox(height: 24),
            const SectionLabel('Ordres de prélèvement'),
            const SizedBox(height: 10),
            _debitsSection(s),

            const SizedBox(height: 24),
            const SectionLabel('Fichier de prélèvement (pain.008)'),
            const SizedBox(height: 10),
            _batchSection(s),
          ],
        ),
      ),
    );
  }

  Widget _notice() => LuxuryCard(
    borderColor: AppColors.champagne.withValues(alpha: 0.45),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.champagne),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aucune transmission bancaire automatique',
                style: AppTypography.title.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'L\'application produit le fichier SEPA (pain.008.001.02) et le journal '
          'des mandats. Le dépôt à la banque reste manuel : il s\'effectue depuis '
          'votre e-banking ou par votre comptable. Chaque ordre doit être '
          'pré-notifié au client au moins 14 jours avant la date de prélèvement '
          '(règlement SEPA) — les ordres non conformes sont exclus du fichier.',
          style: AppTypography.caption.copyWith(color: AppColors.greyLight),
        ),
      ],
    ),
  );

  // ─────────────────────────── MANDATS ───────────────────────────

  Widget _mandatesSection(AppState s) {
    if (s.sepaMandates.isEmpty) {
      return LuxuryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aucun mandat enregistré',
              style: AppTypography.title.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Un mandat est obligatoire avant tout prélèvement : il porte la '
              'signature du client, l\'IBAN du compte à débiter et une référence '
              'unique communiquée à la banque.',
              style: AppTypography.caption.copyWith(color: AppColors.grey),
            ),
          ],
        ),
      );
    }
    return Column(
      children: s.sepaMandates
          .map((m) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _mandateCard(s, m)))
          .toList(),
    );
  }

  Widget _mandateCard(AppState s, SepaMandate m) {
    final active = m.status == SepaMandateStatus.active;
    return LuxuryCard(
      borderColor: active
          ? AppColors.success.withValues(alpha: 0.35)
          : AppColors.grey.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.clientName,
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
              ),
              StatusPill(
                label: m.status.label,
                color: active ? AppColors.success : AppColors.grey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Référence', value: m.mandateReference),
          InfoRow(label: 'Titulaire', value: m.accountHolder),
          InfoRow(label: 'IBAN', value: m.maskedIban),
          InfoRow(label: 'Schéma', value: m.type.label),
          InfoRow(
            label: 'Signé le',
            value: _df.format(m.signatureDate),
          ),
          if (m.lastUsedAt != null)
            InfoRow(
              label: 'Dernier prélèvement',
              value: _df.format(m.lastUsedAt!),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (active)
                GoldButton(
                  label: 'Créer un prélèvement',
                  icon: Icons.add_card_outlined,
                  outlined: true,
                  onPressed: () => _createDebitDialog(s, m),
                ),
              const SizedBox(width: 8),
              if (active && s.can('finance'))
                TextButton(
                  onPressed: () => _revokeDialog(s, m),
                  child: Text(
                    'Révoquer le mandat',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.urgent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── ORDRES DE PRÉLÈVEMENT ───────────────────────

  Widget _debitsSection(AppState s) {
    if (s.sepaDebits.isEmpty) {
      return LuxuryCard(
        child: Text(
          'Aucun ordre de prélèvement. Créez-en un depuis un mandat actif.',
          style: AppTypography.caption.copyWith(color: AppColors.grey),
        ),
      );
    }
    final sorted = [...s.sepaDebits]
      ..sort((a, b) => a.requestedCollectionDate.compareTo(b.requestedCollectionDate));
    return Column(
      children: sorted
          .map((d) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _debitCard(s, d)))
          .toList(),
    );
  }

  Widget _debitCard(AppState s, SepaDebit d) {
    final mandate = s.sepaMandates.firstWhere(
      (m) => m.id == d.mandateId,
      orElse: () => SepaMandate(
        id: '',
        clientId: '',
        clientName: '',
        mandateReference: '',
        iban: '',
        accountHolder: '',
        signatureDate: DateTime(2000),
        createdAt: DateTime(2000),
      ),
    );
    final compliant = d.isPreNotificationCompliant(
      mandate.preNotificationDays == 0 ? 14 : mandate.preNotificationDays,
    );
    final color = switch (d.status) {
      SepaDebitStatus.collected => AppColors.success,
      SepaDebitStatus.rejected => AppColors.urgent,
      SepaDebitStatus.submitted => AppColors.champagne,
      SepaDebitStatus.preNotified => AppColors.statusWaiting,
      _ => AppColors.grey,
    };
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d.clientName} — ${_eur.format(d.amount)}',
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
              ),
              StatusPill(label: d.status.label, color: color),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Échéance',
            value: _df.format(d.requestedCollectionDate),
          ),
          InfoRow(label: 'Séquence', value: d.sequenceType.label),
          InfoRow(label: 'Référence', value: d.endToEndId),
          InfoRow(label: 'Libellé', value: d.remittanceInformation),
          if (d.preNotifiedAt != null)
            InfoRow(
              label: 'Pré-notifié le',
              value: _df.format(d.preNotifiedAt!),
            )
          else
            InfoRow(
              label: 'Pré-notification',
              value: 'non envoyée',
              trailing: Text(
                'À envoyer',
                style: AppTypography.caption.copyWith(
                  color: AppColors.statusWaiting,
                ),
              ),
            ),
          if (d.preNotifiedAt != null && !compliant)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pré-notification trop tardive : 14 jours calendrier exigés avant '
                'l\'échéance. Cet ordre sera exclu du fichier.',
                style: AppTypography.caption.copyWith(color: AppColors.urgent),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (d.status == SepaDebitStatus.draft)
                GoldButton(
                  label: 'Marquer pré-notifié',
                  icon: Icons.mark_email_read_outlined,
                  outlined: true,
                  onPressed: () => _preNotify(s, d),
                ),
              if (d.status == SepaDebitStatus.draft) const SizedBox(width: 8),
              if (d.status == SepaDebitStatus.draft)
                TextButton(
                  onPressed: () => _deleteDraft(s, d),
                  child: Text(
                    'Supprimer',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── GÉNÉRATION DU FICHIER ───────────────────────

  Widget _batchSection(AppState s) {
    final batch = _lastBatch;
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Générer le fichier de prélèvement',
            style: AppTypography.title.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Regroupe les ordres pré-notifiés conformes par date d\'exécution et '
            'par séquence (FRST / RCUR), comme l\'exige le schéma ISO 20022. '
            'Nécessite l\'identifiant créancier SEPA (ICS) et l\'IBAN de '
            'recouvrement renseignés dans les paramètres de la société.',
            style: AppTypography.caption.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GoldButton(
                label: 'Générer le lot',
                icon: Icons.description_outlined,
                onPressed: () => _generate(s),
              ),
              const SizedBox(width: 8),
              if (batch != null && batch.included > 0)
                GoldButton(
                  label: 'Télécharger le XML',
                  icon: Icons.download_outlined,
                  outlined: true,
                  onPressed: () => _download(batch),
                ),
            ],
          ),
          if (batch != null) ...[
            const SizedBox(height: 14),
            if (batch.included > 0) ...[
              InfoRow(
                label: 'Ordres inclus',
                value: '${batch.included}',
                trailing: Icon(
                  Icons.check_circle_outline,
                  size: 15,
                  color: AppColors.success,
                ),
              ),
              InfoRow(
                label: 'Montant total',
                value: _eur.format(batch.total),
              ),
              InfoRow(label: 'Fichier', value: batch.filename),
              const SizedBox(height: 8),
              if (batch.included > 0)
                GoldButton(
                  label: 'Marquer comme transmis à la banque',
                  icon: Icons.outbox_outlined,
                  outlined: true,
                  onPressed: () => _markSubmitted(s, batch),
                ),
            ],
            if (batch.excluded.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Ordres écartés (${batch.excluded.length})',
                style: AppTypography.caption.copyWith(
                  color: AppColors.urgent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...batch.excluded.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• $e',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.greyLight,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── ACTIONS ───────────────────────────

  Future<void> _addMandateDialog(AppState s) async {
    final client = await showDialog<Client>(
      context: context,
      builder: (_) => _ClientPickerDialog(clients: s.clients),
    );
    if (client == null || !mounted) return;

    final holderCtrl = TextEditingController(text: client.fullName);
    final ibanCtrl = TextEditingController();
    final bicCtrl = TextEditingController();
    final refCtrl = TextEditingController(text: s.nextMandateReference());
    var type = SepaMandateType.core;
    var signatureDate = DateTime.now();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Text(
            'Mandat de domiciliation',
            style: AppTypography.title.copyWith(fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client : ${client.fullName}',
                  style: AppTypography.caption.copyWith(color: AppColors.grey),
                ),
                const SizedBox(height: 12),
                _field(refCtrl, 'Référence du mandat', readOnly: true),
                const SizedBox(height: 10),
                _field(holderCtrl, 'Titulaire du compte'),
                const SizedBox(height: 10),
                _field(
                  ibanCtrl,
                  'IBAN du compte à débiter',
                  hint: 'BE68 5390 0754 7034',
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                    LengthLimitingTextInputFormatter(42),
                  ],
                  onChange: (_) => setDlg(() => error = null),
                ),
                const SizedBox(height: 10),
                _field(
                  bicCtrl,
                  'BIC (facultatif en SEPA)',
                  hint: 'GEBABEBB',
                ),
                const SizedBox(height: 14),
                Text(
                  'Type de mandat',
                  style: AppTypography.caption.copyWith(color: AppColors.grey),
                ),
                const SizedBox(height: 6),
                SegmentedButton<SepaMandateType>(
                  segments: SepaMandateType.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                      .toList(),
                  selected: {type},
                  onSelectionChanged: (v) => setDlg(() => type = v.first),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Signé le ${_df.format(signatureDate)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.greyLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: signatureDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDlg(() => signatureDate = picked);
                      },
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.urgent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            GoldButton(
              label: 'Enregistrer',
              onPressed: () {
                final check = SepaValidator.validateIban(ibanCtrl.text);
                if (!check.valid) {
                  setDlg(() => error = check.error);
                  return;
                }
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await s.registerMandate(
        clientId: client.id,
        clientName: client.fullName,
        accountHolder: holderCtrl.text,
        iban: ibanCtrl.text,
        bic: bicCtrl.text,
        signatureDate: signatureDate,
        type: type,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mandat de domiciliation enregistré')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e',
            ),
            backgroundColor: AppColors.urgent,
          ),
        );
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    bool readOnly = false,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChange,
  }) => TextField(
    controller: c,
    readOnly: readOnly,
    inputFormatters: formatters,
    onChanged: onChange,
    style: AppTypography.bodyMedium.copyWith(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.caption.copyWith(color: AppColors.grey),
      hintStyle: AppTypography.caption.copyWith(
        color: AppColors.grey.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: AppColors.anthracite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Future<void> _createDebitDialog(AppState s, SepaMandate m) async {
    final client = s.clients.firstWhere(
      (c) => c.id == m.clientId,
      orElse: () => s.clients.first,
    );
    final tier = s.tierById(client.subscriptionTierId);
    if (tier == null) {
      _snack('Formule d\'abonnement introuvable pour ce client', error: true);
      return;
    }
    var annual = false;
    var date = m.earliestCollectionDate(DateTime.now());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final amount = annual ? tier.annualPrice : tier.monthlyPrice;
          return AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            title: Text(
              'Nouveau prélèvement',
              style: AppTypography.title.copyWith(fontSize: 15),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(label: 'Client', value: client.fullName),
                InfoRow(label: 'Formule', value: tier.name),
                InfoRow(label: 'Montant', value: _eur.format(amount)),
                InfoRow(
                  label: 'Séquence',
                  value: m.nextSequence.label,
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Mensuel')),
                    ButtonSegment(value: true, label: Text('Annuel')),
                  ],
                  selected: {annual},
                  onSelectionChanged: (v) => setDlg(() => annual = v.first),
                ),
                const SizedBox(height: 12),
                Text(
                  'Date d\'exécution minimale : ${_df.format(date)}',
                  style: AppTypography.caption.copyWith(color: AppColors.greyLight),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: m.earliestCollectionDate(DateTime.now()),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (picked != null) setDlg(() => date = picked);
                  },
                  child: const Text('Choisir une autre date'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              GoldButton(
                label: 'Créer',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await s.createSubscriptionDebit(
        clientId: m.clientId,
        collectionDate: date,
        annual: annual,
      );
      _snack('Ordre de prélèvement créé (à pré-notifier avant dépôt)');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _preNotify(AppState s, SepaDebit d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Confirmer la pré-notification',
          style: AppTypography.title.copyWith(fontSize: 15),
        ),
        content: Text(
          'Confirmez-vous avoir informé ${d.clientName} du prélèvement de '
          '${_eur.format(d.amount)} prévu le '
          '${_df.format(d.requestedCollectionDate)} ?\n\n'
          'Cette date est enregistrée dans le journal d\'audit et conditionne '
          'la validité du prélèvement (14 jours minimum).',
          style: AppTypography.caption.copyWith(color: AppColors.greyLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          GoldButton(
            label: 'Confirmer',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await s.markDebitPreNotified(d.id);
    _snack('Pré-notification enregistrée');
  }

  Future<void> _deleteDraft(AppState s, SepaDebit d) async {
    try {
      await s.deleteDebitDraft(d.id);
      _snack('Brouillon supprimé');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _revokeDialog(AppState s, SepaMandate m) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Révoquer le mandat',
          style: AppTypography.title.copyWith(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le mandat ${m.mandateReference} ne pourra plus être prélevé. '
              'Il reste consultable (traçabilité) et la révocation est tracée '
              'dans le journal d\'audit.',
              style: AppTypography.caption.copyWith(color: AppColors.greyLight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              style: AppTypography.bodyMedium.copyWith(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Motif (facultatif)',
                labelStyle: AppTypography.caption.copyWith(color: AppColors.grey),
                filled: true,
                fillColor: AppColors.anthracite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          GoldButton(
            label: 'Révoquer',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await s.revokeMandate(
      m.id,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
    );
    _snack('Mandat révoqué');
  }

  void _generate(AppState s) {
    final batch = s.exportSepaBatch();
    setState(() => _lastBatch = batch);
    if (batch.included == 0) {
      _snack(
        batch.excluded.isEmpty
            ? 'Aucun ordre à inclure'
            : 'Aucun ordre inclus — ${batch.excluded.length} problème(s) détecté(s)',
        error: true,
      );
    } else {
      _snack('${batch.included} ordre(s) prêt(s) — ${_eur.format(batch.total)}');
    }
  }

  void _download(SepaBatchResult batch) {
    final r = exportTextFile(
      filename: batch.filename,
      content: batch.xml,
      mimeType: 'application/xml',
    );
    _snack(r.message ?? (r.ok ? 'Fichier téléchargé' : 'Échec'), error: !r.ok);
  }

  Future<void> _markSubmitted(AppState s, SepaBatchResult batch) async {
    final ids = s.sepaDebits
        .where((d) => d.status == SepaDebitStatus.preNotified)
        .map((d) => d.id)
        .toList();
    if (ids.isEmpty) return;
    try {
      await s.markBatchSubmitted(
        ids,
        batchId: batch.filename.replaceAll('.xml', ''),
      );
      _snack('Lot marqué comme transmis');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.urgent : null,
      ),
    );
  }
}

/// Sélection du client pour un nouveau mandat.
class _ClientPickerDialog extends StatelessWidget {
  final List<Client> clients;
  const _ClientPickerDialog({required this.clients});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text(
        'Choisir le client',
        style: AppTypography.title.copyWith(fontSize: 15),
      ),
      content: SizedBox(
        width: 420,
        child: clients.isEmpty
            ? Text(
                'Aucun client enregistré.',
                style: AppTypography.caption.copyWith(color: AppColors.grey),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: clients.length,
                itemBuilder: (ctx, i) {
                  final c = clients[i];
                  return ListTile(
                    title: Text(
                      c.fullName,
                      style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                    ),
                    subtitle: Text(
                      c.email,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
