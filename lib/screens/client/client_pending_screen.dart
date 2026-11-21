import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../account/my_account_edit_screen.dart';
import '../legal/legal_hub_screen.dart';

/// Écran présenté à un client dont le dossier n'est pas encore accepté.
///
/// ── POURQUOI CET ÉCRAN EXISTE ─────────────────────────────────────────
/// L'inscription est publique, mais l'accès aux services de conciergerie est
/// réservé aux dossiers validés par le personnel. Ce client s'est authentifié
/// correctement : on ne le renvoie donc PAS vers l'écran de connexion, ce qui
/// laisserait croire à un échec. On lui explique où en est son dossier, ce
/// qu'il peut faire en attendant, et comment nous joindre.
///
/// Il remplace entièrement l'espace client : aucune demande, réservation,
/// facture ni conversation n'est accessible tant que la décision n'est pas
/// prise.
class ClientPendingScreen extends StatelessWidget {
  const ClientPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final client = s.currentClient;
    final rejected = client?.isRejected ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const GorexBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => s.logout(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Icon(
                    rejected
                        ? Icons.report_gmailerrorred_outlined
                        : Icons.hourglass_top_outlined,
                    size: 44,
                    color: rejected ? AppColors.urgent : AppColors.champagne,
                  ),
                ),
                const SizedBox(height: 20),
                GoldDivider(width: 46),
                const SizedBox(height: 22),
                Text(
                  rejected ? 'DOSSIER NON RETENU' : 'DOSSIER EN COURS D\'EXAMEN',
                  style: AppTypography.eyebrow,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  rejected
                      ? 'Votre inscription n\'a pas été acceptée'
                      : 'Votre inscription est bien enregistrée',
                  style: AppTypography.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.divider, width: 0.6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (client != null) ...[
                        // Le numéro de dossier définitif n'existe pas encore :
                        // il sera réservé par l'équipe au moment de la
                        // validation. Tant qu'il n'est pas attribué, on
                        // n'affiche rien plutôt qu'un numéro provisoire
                        // (« GRX-ATTENTE-… ») que le client prendrait pour sa
                        // référence et citerait dans ses échanges.
                        if (client.hasAssignedCode) ...[
                          InfoRow(label: 'Dossier', value: client.code),
                          const SizedBox(height: 8),
                        ],
                        InfoRow(label: 'Titulaire', value: client.fullName),
                        const SizedBox(height: 8),
                        InfoRow(label: 'Adresse', value: client.email),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        rejected
                            ? 'Votre dossier a été examiné et n\'a pas été '
                                  'retenu. Aucune donnée de votre compte n\'a '
                                  'été conservée ni transmise à un tiers. '
                                  'Pour connaître le motif ou déposer une '
                                  'nouvelle demande, écrivez-nous.'
                            : 'Chaque dossier est vérifié personnellement par '
                                  'notre équipe, afin de garantir la '
                                  'confidentialité et la qualité du service. '
                                  'Vous recevrez une confirmation dès que '
                                  'votre accès sera ouvert. Vos informations '
                                  'sont déjà enregistrées : vous n\'avez rien '
                                  'à refaire.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Besoin d\'une réponse rapide ? Écrivez à '
                        '${AppConfig.supportEmail}.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (!rejected) ...[
                  GoldButton(
                    label: 'Actualiser mon statut',
                    icon: Icons.refresh,
                    fullWidth: true,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Vérification en cours…')),
                      );
                      await s.refreshMyClientStatus();
                      if (!context.mounted) return;
                      final stillPending =
                          s.currentClient?.isPending ?? true;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            stillPending
                                ? 'Votre dossier est toujours en cours '
                                      'd\'examen. Merci de votre patience.'
                                : 'Votre dossier a évolué : votre espace '
                                      's\'ouvre.',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyAccountEditScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('COMPLÉTER MES INFORMATIONS'),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalHubScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.gavel_outlined, size: 15),
                    label: const Text('INFORMATIONS LÉGALES'),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => s.logout(),
                    child: const Text('SE DÉCONNECTER'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
