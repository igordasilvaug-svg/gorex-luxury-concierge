import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/client.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// File d'attente des inscriptions clients, réservée au personnel habilité.
///
/// ── POURQUOI CET ÉCRAN EXISTE ─────────────────────────────────────────
/// Le formulaire d'inscription est public : n'importe qui peut déposer un
/// dossier. Sans point de contrôle, une personne inconnue s'attribuait le
/// premier palier d'abonnement et adressait des demandes à la conciergerie,
/// donc consommait du temps de votre équipe.
///
/// Chaque dossier déposé arrive ici en « En attente ». Tant qu'il n'est pas
/// accepté, la personne se connecte mais ne voit AUCUN service : elle est
/// reçue par un écran d'attente qui explique où en est son dossier.
///
/// ── DÉCISIONS POSSIBLES ───────────────────────────────────────────────
///   • Accepter : le dossier passe en « Validé », l'accès aux services ouvre.
///   • Refuser  : le motif est enregistré et communiqué à la personne.
///   • Suspendre / réactiver : pour un dossier déjà validé (impayé, incident).
class ClientApprovalsScreen extends StatelessWidget {
  const ClientApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pending = s.pendingClientApprovals;
    final decided = s.clients.where((c) => !c.isPending).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        children: [
          Text('Validation des clients', style: AppTypography.displayMedium),
          const SizedBox(height: 6),
          Text(
            'L\'inscription est publique : chaque dossier doit être accepté '
            'avant d\'ouvrir l\'accès aux services de conciergerie.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 24),

          // ─────────── À traiter ───────────
          Row(
            children: [
              const SectionLabel('Dossiers à traiter'),
              const SizedBox(width: 10),
              StatusPill(
                label: '${pending.length}',
                color: pending.isEmpty ? AppColors.success : AppColors.statusWaiting,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            LuxuryCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucun dossier en attente. Toute nouvelle inscription '
                      'apparaîtra ici.',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final c in pending) ...[
              _ApprovalCard(client: c),
              const SizedBox(height: 10),
            ],

          const SizedBox(height: 26),

          // ─────────── Historique ───────────
          const SectionLabel('Dossiers traités'),
          const SizedBox(height: 12),
          if (decided.isEmpty)
            Text('Aucun dossier traité pour le moment.', style: AppTypography.caption)
          else
            for (final c in decided) ...[
              _DecidedCard(client: c),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

/// Dossier en attente, avec les deux décisions possibles.
class _ApprovalCard extends StatefulWidget {
  const _ApprovalCard({required this.client});
  final Client client;

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _busy = false;

  Future<void> _approve(AppState s) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.approveClient(widget.client.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${widget.client.email} a été validé.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Validation impossible : $e'),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reject(AppState s) async {
    // Le messager est capturé AVANT l'ouverture de la boîte de dialogue :
    // après l'attente, le contexte peut avoir été démonté.
    final messenger = ScaffoldMessenger.of(context);
    final motif = await _askReason(context);
    if (motif == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await s.rejectClient(widget.client.id, reason: motif);
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.client.email} a été refusé.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Refus impossible : $e'),
          backgroundColor: AppColors.urgent,
        ),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = widget.client;

    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_reg_outlined,
                size: 16,
                color: AppColors.statusWaiting,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.fullName,
                  style: AppTypography.title.copyWith(fontSize: 15),
                ),
              ),
              StatusPill(
                label: c.approvalStatus.label,
                color: AppColors.statusWaiting,
              ),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Dossier', value: c.code),
          const SizedBox(height: 6),
          InfoRow(label: 'E-mail', value: c.email),
          if (c.phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            InfoRow(label: 'Téléphone', value: c.phone),
          ],
          if (c.companyName != null && c.companyName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InfoRow(label: 'Société', value: c.companyName!),
          ],
          if (c.companyNumber != null && c.companyNumber!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InfoRow(label: 'N° d\'entreprise', value: c.companyNumber!),
          ],
          if (c.vatNumber != null && c.vatNumber!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InfoRow(label: 'TVA', value: c.vatNumber!),
          ],
          const SizedBox(height: 6),
          InfoRow(
            label: 'Localité',
            value: [
              c.city,
              c.country,
            ].where((e) => e.trim().isNotEmpty).join(', '),
          ),
          const SizedBox(height: 6),
          InfoRow(
            label: 'Déposé le',
            value: DateFormat('dd/MM/yyyy HH:mm', 'fr_BE').format(c.createdAt),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            // Sur téléphone, deux boutons côte à côte ne tiennent pas : on les
            // empile pour que les libellés restent lisibles.
            builder: (context, constraints) {
              final approuver = GoldButton(
                label: _busy ? 'Enregistrement…' : 'Accepter le dossier',
                icon: Icons.check_circle_outline,
                onPressed: _busy ? null : () => _approve(s),
              );
              final refuser = GoldButton(
                label: 'Refuser',
                icon: Icons.block_outlined,
                outlined: true,
                onPressed: _busy ? null : () => _reject(s),
              );
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    approuver,
                    const SizedBox(height: 10),
                    refuser,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: approuver),
                  const SizedBox(width: 10),
                  Expanded(child: refuser),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Dossier déjà traité : consultation de la décision.
class _DecidedCard extends StatefulWidget {
  const _DecidedCard({required this.client});
  final Client client;

  @override
  State<_DecidedCard> createState() => _DecidedCardState();
}

class _DecidedCardState extends State<_DecidedCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = widget.client;
    final refuse = c.isRejected;
    final couleur = refuse
        ? AppColors.urgent
        : (c.active ? AppColors.success : AppColors.statusWaiting);
    final libelle = refuse
        ? 'Refusé'
        : (c.active ? 'Validé' : 'Suspendu');

    return LuxuryCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.fullName,
                  style: AppTypography.title.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(c.email, style: AppTypography.caption),
              ],
            ),
          ),
          StatusPill(label: libelle, color: couleur),
          const SizedBox(width: 8),
          if (!refuse)
            IconButton(
              tooltip: c.active ? 'Suspendre l\'accès' : 'Réactiver l\'accès',
              icon: Icon(
                c.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 20,
                color: AppColors.grey,
              ),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await s.setClientActive(c.id, !c.active);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Modification impossible : $e'),
                            backgroundColor: AppColors.urgent,
                          ),
                        );
                      }
                      if (mounted) setState(() => _busy = false);
                    },
            ),
        ],
      ),
    );
  }
}

/// Demande le motif de refus. Retourne `null` si la personne renonce.
///
/// Le motif est OBLIGATOIRE : refuser sans explication priverait la personne
/// de tout moyen de comprendre ou de corriger son dossier.
Future<String?> _askReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Motif du refus', style: AppTypography.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ce motif est enregistré et servira de réponse à la personne.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
            decoration: const InputDecoration(
              labelText: 'Motif',
              hintText: 'Ex. : dossier incomplet, demande hors périmètre…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('ANNULER'),
        ),
        TextButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isEmpty) return; // motif obligatoire
            Navigator.of(ctx).pop(v);
          },
          child: const Text('REFUSER'),
        ),
      ],
    ),
  );
}
