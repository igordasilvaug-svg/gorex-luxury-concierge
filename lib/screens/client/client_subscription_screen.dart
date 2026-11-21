// GOREX LUXURY CONCIERGE — Espace client : mon abonnement.
//
// ── CE QUE CET ÉCRAN CORRIGE ──────────────────────────────────────────────
// Avant, un client n'avait AUCUN moyen de consulter ni de demander une
// formule : l'écran des abonnements est réservé au personnel (`permission:
// 'subscriptions'` = CEO). Le palier affiché sur son profil était celui que
// l'inscription lui avait attribué d'office, présenté comme un « Contrat
// annuel » alors qu'il n'avait rien demandé, rien signé et rien payé.
//
// Cet écran dit la vérité sur l'état réel :
//   • aucun abonnement → « Aucun abonnement en cours », pas de faux contrat ;
//   • demande envoyée  → la demande est datée, sans montant dû ;
//   • acceptée         → le contrat est formé, en attente du mandat ;
//   • active           → seule situation où une facturation existe ;
//   • offre fermée     → l'interrupteur `SubscriptionPolicy` interdit la
//                        souscription, et l'écran l'annonce au lieu de
//                        proposer un bouton qui échouerait.
//
// Aucune souscription ne peut être enregistrée tant que
// `SubscriptionPolicy.subscriptionsOpen` vaut false : l'écran ne fait
// qu'obéir au verrou posé dans l'état métier.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/billing/subscription_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/client.dart';
import '../../models/sepa_mandate.dart';
import '../../models/subscription.dart';
import '../../models/subscription_tier.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class ClientSubscriptionScreen extends StatelessWidget {
  const ClientSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final sub = s.mySubscription;

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon abonnement')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profil indisponible',
          message: 'Aucun dossier client associé à ce compte.',
        ),
      );
    }

    final mandate = s.mandateForClient(client.id);
    final mandat = _dateFmt;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          children: [
            // ── État contractuel réel ────────────────────────────────────
            if (sub == null) const _NoSubscriptionCard() else _SubscriptionCard(sub),

            const SizedBox(height: 20),

            // ── Verrou d'ouverture commerciale ───────────────────────────
            if (!SubscriptionPolicy.subscriptionsOpen) ...[
              const _ClosedOfferCard(),
              const SizedBox(height: 20),
            ],

            // ── Choix de la formule ──────────────────────────────────────
            // Affiché uniquement si aucune demande n'est déjà en cours : on ne
            // laisse pas un client empiler les demandes, ce qui rendrait la
            // situation illisible pour l'équipe.
            if (sub == null || sub.status == SubscriptionStatus.ended) ...[
              SectionHeader(title: 'Les formules'),
              const SizedBox(height: 12),
              ..._tierCards(context, s, client),
              const SizedBox(height: 20),
            ],

            // ── Mandat de paiement ───────────────────────────────────────
            if (sub != null && sub.status != SubscriptionStatus.ended) ...[
              SectionHeader(title: 'Mandat de prélèvement (SEPA)'),
              const SizedBox(height: 12),
              if (mandate != null)
                _MandateCard(mandate: mandate, dateFmt: mandat)
              else
                _MandateForm(
                  client: client,
                  enabled: client.hasServiceAccess,
                  onSigned: (m) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mandat ${m.mandateReference} enregistré '
                          '(${m.maskedIban}). Aucun prélèvement n\'aura lieu '
                          'sans abonnement actif.',
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],

            // ── Explication du circuit ───────────────────────────────────
            const SectionHeader(title: 'Comment ça marche'),
            const SizedBox(height: 12),
            const _ProcessCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy', 'fr_BE');

  /// Une carte par formule de la grille réellement chargée.
  List<Widget> _tierCards(
    BuildContext context,
    AppState s,
    Client client,
  ) {
    final eur = NumberFormat.currency(locale: 'fr_BE', symbol: '€', decimalDigits: 0);
    final active = s.tiers.where((t) => t.active).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    if (active.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.info_outline,
          title: 'Grille en cours de publication',
          message: 'Aucune formule n\'est disponible pour le moment.',
        ),
      ];
    }

    return active.map((t) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _TierCard(
          tier: t,
          priceLabel: '${eur.format(t.annualPrice)} / an',
          monthlyLabel: 'ou ${eur.format(t.monthlyPrice)} / mois',
          onSelect: () => _chooseCycle(context, s, client, t),
        ),
      );
    }).toList();
  }

  /// Choix du rythme de facturation, puis dépôt de la demande.
  ///
  /// Le bouton n'est proposé que si l'offre est ouverte : dans le cas
  /// contraire, l'état métier refuserait l'écriture et l'écran aurait menti.
  Future<void> _chooseCycle(
    BuildContext context,
    AppState s,
    Client client,
    SubscriptionTier tier,
  ) async {
    if (!SubscriptionPolicy.subscriptionsOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(SubscriptionPolicy.closedNotice)),
      );
      return;
    }

    final cycle = await showModalBottomSheet<BillingCycle>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tier.name, style: AppTypography.headline),
              const SizedBox(height: 6),
              Text(
                'Choisissez votre rythme de facturation.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 18),
              for (final c in BillingCycle.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GoldButton(
                    label: '${c.label} — ${_amountFor(tier, c)}',
                    fullWidth: true,
                    outlined: c != BillingCycle.annual,
                    onPressed: () => Navigator.pop(context, c),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (cycle == null || !context.mounted) return;

    try {
      await s.requestSubscription(
        clientId: client.id,
        tierId: tier.id,
        cycle: cycle,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Votre demande a été enregistrée sur le serveur. '
            'Aucun montant n\'est dû avant l\'acceptation de Gorex Group.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('n\'est pas encore ouverte')
                ? SubscriptionPolicy.closedNotice
                : 'La demande n\'a pas pu être enregistrée. '
                      'Vérifiez votre connexion et réessayez.',
          ),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
  }

  static String _amountFor(SubscriptionTier t, BillingCycle c) {
    final eur = NumberFormat.currency(locale: 'fr_BE', symbol: '€', decimalDigits: 0);
    return c == BillingCycle.annual
        ? '${eur.format(t.annualPrice)} / an'
        : '${eur.format(t.monthlyPrice)} / mois';
  }
}

// ═══════════════════════════ CARTES D'ÉTAT ═══════════════════════════

/// Aucun abonnement : c'est l'état par défaut, et il doit être dit tel quel.
class _NoSubscriptionCard extends StatelessWidget {
  const _NoSubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: AppColors.greyLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucun abonnement en cours',
                  style: AppTypography.title.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Votre compte ne comporte à ce jour aucune formule souscrite. '
            'Aucun montant ne vous est facturé au titre d\'un abonnement.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

/// Abonnement existant : uniquement des faits datés, rien de promotionnel.
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard(this.sub);
  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy', 'fr_BE');
    final color = switch (sub.status) {
      SubscriptionStatus.active => AppColors.success,
      SubscriptionStatus.approved => AppColors.statusProgress,
      SubscriptionStatus.requested => AppColors.statusWaiting,
      SubscriptionStatus.suspended => AppColors.statusWaiting,
      SubscriptionStatus.ended => AppColors.grey,
    };

    return LuxuryCard(
      highlighted: sub.status == SubscriptionStatus.active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sub.tierName.isEmpty ? 'Formule' : sub.tierName,
                  style: AppTypography.title.copyWith(
                    fontSize: 15,
                    letterSpacing: 1.2,
                    color: sub.status == SubscriptionStatus.active
                        ? AppColors.champagne
                        : AppColors.offWhite,
                  ),
                ),
              ),
              StatusPill(label: sub.status.label, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(sub.status.description, style: AppTypography.caption),
          const Divider(height: 22),
          InfoRow(label: 'Montant convenu', value: sub.amountLabel),
          const Divider(height: 1),
          InfoRow(label: 'Rythme', value: sub.cycle.label),
          const Divider(height: 1),
          InfoRow(label: 'Demandé le', value: df.format(sub.requestedAt)),
          if (sub.decidedAt != null) ...[
            const Divider(height: 1),
            InfoRow(label: 'Décision le', value: df.format(sub.decidedAt!)),
          ],
          if (sub.activatedAt != null) ...[
            const Divider(height: 1),
            InfoRow(
              label: 'Date d\'effet',
              value: df.format(sub.activatedAt!),
            ),
          ],
          if (sub.note != null && sub.note!.trim().isNotEmpty) ...[
            const Divider(height: 1),
            InfoRow(label: 'Note', value: sub.note!),
          ],
          if (!sub.isBillable) ...[
            const SizedBox(height: 12),
            Text(
              'Aucune facturation n\'est en cours pour cet abonnement.',
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.greyLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Offre fermée : on explique au lieu de laisser croire à une panne.
class _ClosedOfferCard extends StatelessWidget {
  const _ClosedOfferCard();

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      borderColor: AppColors.statusWaiting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                size: 16,
                color: AppColors.statusWaiting,
              ),
              const SizedBox(width: 10),
              Text(
                SubscriptionPolicy.closedBadge,
                style: AppTypography.label.copyWith(
                  fontSize: 10,
                  color: AppColors.statusWaiting,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(SubscriptionPolicy.closedNotice, style: AppTypography.caption),
          const SizedBox(height: 8),
          Text(
            'Besoin d\'un accompagnement dès maintenant ? Écrivez à votre '
            'concierge : les demandes de service restent ouvertes.',
            style: AppTypography.caption.copyWith(
              fontSize: 10.5,
              color: AppColors.greyLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une formule de la grille.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.priceLabel,
    required this.monthlyLabel,
    required this.onSelect,
  });

  final SubscriptionTier tier;
  final String priceLabel;
  final String monthlyLabel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tier.name,
            style: AppTypography.title.copyWith(
              fontSize: 14,
              letterSpacing: 1.4,
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(height: 6),
          Text(tier.tagline, style: AppTypography.caption),
          const Divider(height: 20),
          InfoRow(label: 'Tarif annuel', value: priceLabel),
          const Divider(height: 1),
          InfoRow(label: 'Tarif mensuel', value: monthlyLabel),
          const Divider(height: 1),
          InfoRow(label: 'Demandes', value: tier.requestsLabel),
          const Divider(height: 1),
          InfoRow(label: 'Réponse', value: '< ${tier.responseMinutes} min'),
          const Divider(height: 1),
          InfoRow(label: 'Disponibilité', value: tier.availability),
          if (tier.includedServices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tier.includedServices
                  .take(6)
                  .map(
                    (e) => StatusPill(
                      label: e,
                      color: AppColors.greyLight,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          if (SubscriptionPolicy.subscriptionsOpen)
            GoldButton(
              label: 'Demander cette formule',
              icon: Icons.arrow_forward,
              fullWidth: true,
              onPressed: onSelect,
            )
          else
            OutlinedButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.lock_outline, size: 15),
              label: const Text('SOUSCRIPTION NON OUVERTE'),
            ),
        ],
      ),
    );
  }
}

/// Mandat déjà signé : on ne réaffiche jamais l'IBAN en clair.
class _MandateCard extends StatelessWidget {
  const _MandateCard({required this.mandate, required this.dateFmt});
  final SepaMandate mandate;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final color = mandate.status == SepaMandateStatus.active
        ? AppColors.success
        : AppColors.statusWaiting;
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mandate.maskedIban,
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
              ),
              StatusPill(label: mandate.status.label, color: color),
            ],
          ),
          const Divider(height: 20),
          InfoRow(label: 'Titulaire', value: mandate.accountHolder),
          const Divider(height: 1),
          InfoRow(label: 'Référence', value: mandate.mandateReference),
          const Divider(height: 1),
          InfoRow(
            label: 'Signé le',
            value: dateFmt.format(mandate.signatureDate),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun prélèvement n\'est effectué tant que votre abonnement n\'est '
            'pas actif. Vous pouvez le révoquer à tout moment en écrivant à '
            'votre concierge.',
            style: AppTypography.caption.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// Signature du mandat par le client : c'est le débiteur qui signe.
class _MandateForm extends StatefulWidget {
  const _MandateForm({
    required this.client,
    required this.enabled,
    required this.onSigned,
  });

  final Client client;
  final bool enabled;
  final void Function(SepaMandate) onSigned;

  @override
  State<_MandateForm> createState() => _MandateFormState();
}

class _MandateFormState extends State<_MandateForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holder = TextEditingController(
    text: widget.client.fullName,
  );
  final _iban = TextEditingController();
  final _bic = TextEditingController();
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _holder.dispose();
    _iban.dispose();
    _bic.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Cochez la case d\'accord pour signer le mandat.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = await context.read<AppState>().signMandateAsClient(
        accountHolder: _holder.text,
        iban: _iban.text,
        bic: _bic.text,
        acceptedTerms: _accepted,
      );
      if (!mounted) return;
      widget.onSigned(m);
      setState(() {
        _iban.clear();
        _bic.clear();
        _accepted = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return LuxuryCard(
        child: Text(
          'La signature d\'un mandat de paiement sera possible dès que votre '
          'dossier aura été validé par Gorex Group.',
          style: AppTypography.caption,
        ),
      );
    }

    return LuxuryCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous êtes le débiteur : seul le titulaire du compte peut signer '
              'ce mandat.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _holder,
              decoration: const InputDecoration(labelText: 'Titulaire du compte'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Indiquez le titulaire du compte'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _iban,
              decoration: const InputDecoration(
                labelText: 'IBAN',
                hintText: 'BE00 0000 0000 0000',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'IBAN incomplet'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bic,
              decoration: const InputDecoration(
                labelText: 'BIC (facultatif)',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'J\'autorise Gorex Group à prélever les montants de mon '
                'abonnement sur ce compte, et je peux le révoquer à tout moment.',
                style: AppTypography.caption,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.caption.copyWith(color: AppColors.urgent),
              ),
            ],
            const SizedBox(height: 12),
            GoldButton(
              label: _busy ? 'Enregistrement…' : 'Signer le mandat',
              icon: Icons.draw_outlined,
              fullWidth: true,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 10),
            Text(
              'Votre IBAN n\'est jamais réaffiché en clair : seul un format '
              'masqué est présenté ensuite.',
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rappel du circuit, sans promesse commerciale.
class _ProcessCard extends StatelessWidget {
  const _ProcessCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('1', 'Vous choisissez une formule', 'Aucun montant n\'est dû.'),
      ('2', 'Gorex Group étudie la demande', 'Réponse datée et nominative.'),
      ('3', 'Vous signez le mandat SEPA', 'Le débiteur signe lui-même.'),
      ('4', 'Le contrat devient actif', 'Seule étape où la facturation existe.'),
    ];
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (n, title, detail) in steps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.champagneDark, width: 0.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    n,
                    style: AppTypography.label.copyWith(
                      fontSize: 10,
                      color: AppColors.champagne,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(fontSize: 12.5),
                      ),
                      Text(detail, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            if (n != '4') const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}
