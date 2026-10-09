import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Sauvegarde & restauration des données locales.
///
/// Permet d'exporter l'intégralité des données (clients, demandes, finances,
/// agenda, journal d'audit...) dans un fichier JSON, et de les restaurer
/// ensuite. Aucune donnée ne quitte l'appareil : l'export est copié dans le
/// presse-papiers ou partagé via le partage natif.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _copyBackup() async {
    final s = context.read<AppState>();
    final json = s.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    _snack(
      'Sauvegarde copiée (${_ko(json)} · ${s.dataCounts['clients']} clients).',
    );
  }

  Future<void> _shareBackup() async {
    setState(() => _busy = true);
    try {
      final s = context.read<AppState>();
      final json = s.exportJson();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final bytes = Uint8List.fromList(utf8.encode(json));
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'gorex-sauvegarde-$stamp.json',
      );
    } catch (e) {
      _snack('Export indisponible sur cet appareil.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importDialog() async {
    final ctrl = TextEditingController();
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer une sauvegarde'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collez le contenu JSON de la sauvegarde. '
                'Les données actuelles seront remplacées.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 8,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: '{ "app": "GOREX LUXURY CONCIERGE", ... }',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      ctrl.dispose();
      return;
    }
    final raw = ctrl.text.trim();
    ctrl.dispose();
    if (raw.isEmpty) {
      _snack('Aucune donnée collée.');
      return;
    }

    setState(() => _busy = true);
    try {
      await state.importJson(raw);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restauration réussie'),
          content: const Text(
            'Les données ont été restaurées. Par sécurité, veuillez vous '
            'reconnecter.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Restauration impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmWipe() async {
    final state = context.read<AppState>();
    final ok = await _confirm(
      title: 'Tout effacer ?',
      message:
          'Toutes les données locales seront définitivement supprimées. '
          'Pensez à exporter une sauvegarde avant de continuer.',
      action: 'Effacer',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await state.wipeAll();
      _snack('Données locales effacées.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    final state = context.read<AppState>();
    final ok = await _confirm(
      title: 'Réinitialiser la démonstration ?',
      message:
          'Les données de démonstration d\'origine seront restaurées. '
          'Vos modifications locales seront perdues.',
      action: 'Réinitialiser',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await state.resetDemo();
      _snack('Données de démonstration restaurées.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _pushCloud() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final at = await state.pushToCloud();
      _snack('État synchronisé vers le cloud — ${_fmt(at)}.');
    } on CloudException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Synchronisation impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pullCloud() async {
    final state = context.read<AppState>();
    final ok = await _confirm(
      title: 'Récupérer depuis le cloud ?',
      message:
          'Les données locales seront remplacées par la dernière version '
          'sauvegardée dans le cloud. La session sera close par sécurité.',
      action: 'Récupérer',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final at = await state.pullFromCloud();
      if (!mounted) return;
      if (at == null) {
        _snack('Aucune sauvegarde cloud disponible.');
      } else {
        _snack('Données cloud restaurées — ${_fmt(at)}.');
      }
    } on CloudException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Récupération impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _cloudPill(bool available) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (available ? AppColors.success : AppColors.grey).withValues(
        alpha: 0.14,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (available ? AppColors.success : AppColors.grey).withValues(
          alpha: 0.5,
        ),
        width: 0.8,
      ),
    ),
    child: Text(
      available ? 'CONNECTÉ' : 'LOCAL',
      style: AppTypography.eyebrow.copyWith(
        fontSize: 9,
        color: available ? AppColors.success : AppColors.grey,
      ),
    ),
  );

  String _fmt(DateTime d) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(d.day)}/${p2(d.month)}/${d.year} ${p2(d.hour)}:${p2(d.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _ko(String json) {
    final b = json.length;
    if (b < 1024) return '$b o';
    return '${(b / 1024).toStringAsFixed(1)} Ko';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final counts = s.dataCounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde & restauration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Intégrité des données'),
                  const SizedBox(height: 10),
                  Text(
                    'Sauvegarde & restauration',
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Exportez l\'intégralité de vos données dans un fichier '
                    'JSON, ou restaurez une sauvegarde existante. '
                    'Aucune donnée n\'est transmise à un tiers.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 18),

                  // ── Contenu actuel ──
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CONTENU ACTUEL', style: AppTypography.eyebrow),
                        const SizedBox(height: 12),
                        _grid(counts),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Exporter ──
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.save_alt,
                              size: 18,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 10),
                            Text('Exporter', style: AppTypography.title),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Génère un fichier de sauvegarde horodaté incluant '
                          'clients, demandes, finances, agenda et journal d\'audit.',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            GoldButton(
                              label: 'Partager / Enregistrer',
                              icon: Icons.ios_share,
                              onPressed: _busy ? null : _shareBackup,
                            ),
                            GoldButton(
                              label: 'Copier le JSON',
                              icon: Icons.copy_all_outlined,
                              outlined: true,
                              onPressed: _busy ? null : _copyBackup,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Restaurer ──
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.settings_backup_restore,
                              size: 18,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 10),
                            Text('Restaurer', style: AppTypography.title),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Collez le contenu d\'une sauvegarde JSON. '
                          'Les données actuelles seront remplacées et la '
                          'session sera close par sécurité.',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 14),
                        GoldButton(
                          label: 'Coller une sauvegarde',
                          icon: Icons.content_paste,
                          outlined: true,
                          onPressed: _busy ? null : _importDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Cloud (Firestore) ──
                  LuxuryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.cloud_outlined,
                              size: 18,
                              color: AppColors.champagne,
                            ),
                            const SizedBox(width: 10),
                            Text('Synchronisation Cloud', style: AppTypography.title),
                            const Spacer(),
                            _cloudPill(s.cloudAvailable),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.cloudAvailable
                              ? 'Le backend Firestore GOREX est connecté. '
                                    'Vous pouvez envoyer ou récupérer l\'état '
                                    'complet depuis le cloud sécurisé.'
                              : 'Backend Cloud non initialisé sur cet appareil. '
                                    'L\'application fonctionne en mode local '
                                    '(aucune donnée n\'est transmise).',
                          style: AppTypography.caption,
                        ),
                        if (s.lastCloudSync != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Dernière synchro : '
                            '${_fmt(s.lastCloudSync!)}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.champagne,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            GoldButton(
                              label: 'Envoyer vers le cloud',
                              icon: Icons.cloud_upload_outlined,
                              onPressed:
                                  (_busy || !s.cloudAvailable) ? null : _pushCloud,
                            ),
                            GoldButton(
                              label: 'Récupérer du cloud',
                              icon: Icons.cloud_download_outlined,
                              outlined: true,
                              onPressed:
                                  (_busy || !s.cloudAvailable) ? null : _pullCloud,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Zone sensible ──
                  LuxuryCard(
                    borderColor: AppColors.urgent.withValues(alpha: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: AppColors.urgent,
                            ),
                            const SizedBox(width: 10),
                            Text('Zone sensible', style: AppTypography.title),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ces actions sont irréversibles. Exportez d\'abord '
                          'une sauvegarde.',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _confirmReset,
                              icon: const Icon(Icons.restart_alt, size: 16),
                              label: const Text('Réinitialiser la démo'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _confirmWipe,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.urgent,
                                side: BorderSide(
                                  color: AppColors.urgent.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_forever_outlined,
                                size: 16,
                              ),
                              label: const Text('Tout effacer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(Map<String, int> counts) {
    const labels = <String, String>{
      'clients': 'Clients',
      'requests': 'Demandes',
      'providers': 'Prestataires',
      'bookings': 'Réservations',
      'itineraries': 'Itinéraires',
      'financeDocs': 'Documents',
      'expenses': 'Dépenses',
      'users': 'Comptes',
      'auditLog': 'Audit',
    };
    final entries = labels.entries.toList();
    return LayoutBuilder(
      builder: (_, c) {
        final cols = c.maxWidth < 520 ? 2 : 3;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            for (final e in entries)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.anthracite,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.divider, width: 0.6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${counts[e.key] ?? 0}',
                      style: AppTypography.numberLarge.copyWith(fontSize: 22),
                    ),
                    Text(
                      e.value.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(
                        fontSize: 9,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
