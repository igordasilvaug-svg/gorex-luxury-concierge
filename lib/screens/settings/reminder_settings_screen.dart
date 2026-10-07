import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/billing/reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/reminder_config.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Configuration du moteur de relance automatique des factures impayées.
///
/// Permet de planifier l'envoi des relances (1ʳᵉ, 2ᵉ, mise en demeure) au
/// démarrage de l'app et/ou à intervalle régulier, sans intervention manuelle.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  late TextEditingController _interval;
  late TextEditingController _minDays;
  bool _enabled = false;
  bool _autoSend = true;
  bool _runOnStartup = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().reminderConfig;
    _interval = TextEditingController(text: c.intervalHours.toString());
    _minDays = TextEditingController(text: c.minDaysBetween.toString());
    _enabled = c.enabled;
    _autoSend = c.autoSend;
    _runOnStartup = c.runOnStartup;
  }

  @override
  void dispose() {
    _interval.dispose();
    _minDays.dispose();
    super.dispose();
  }

  ReminderConfig _collect() {
    final s = context.read<AppState>();
    return s.reminderConfig.copyWith(
      enabled: _enabled,
      autoSend: _autoSend,
      runOnStartup: _runOnStartup,
      intervalHours: int.tryParse(_interval.text.trim()) ?? 24,
      minDaysBetween: int.tryParse(_minDays.text.trim()) ?? 7,
    );
  }

  Future<void> _save() async {
    await context.read<AppState>().updateReminderConfig(_collect());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration des relances enregistrée.')),
      );
    }
  }

  Future<void> _runNow() async {
    setState(() => _running = true);
    final s = context.read<AppState>();
    await s.updateReminderConfig(_collect());
    final n = await s.runAutoReminders(force: true);
    if (!mounted) return;
    setState(() => _running = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'Aucune relance à envoyer.'
              : '$n relance(s) traitée(s).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cfg = s.reminderConfig;
    final pending = ReminderService.pending(
      s.financeDocs,
      minDays: cfg.minDaysBetween,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relances automatiques', style: AppTypography.displayMedium),
            const SizedBox(height: 5),
            Text(
              'Planification de l\'envoi des rappels de factures impayées',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),

            // État du moteur
            LuxuryCard(
              highlighted: cfg.enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cfg.enabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        size: 18,
                        color: cfg.enabled
                            ? AppColors.statusConfirmed
                            : AppColors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cfg.enabled
                              ? 'Moteur de relance actif'
                              : 'Moteur de relance inactif',
                          style: AppTypography.title.copyWith(fontSize: 14),
                        ),
                      ),
                      StatusPill(
                        label: cfg.enabled ? 'Actif' : 'Inactif',
                        color: cfg.enabled
                            ? AppColors.statusConfirmed
                            : AppColors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    label: 'En attente',
                    value: '${pending.length} relance(s) à envoyer',
                  ),
                  const Divider(height: 1),
                  InfoRow(
                    label: 'Dernière exéc.',
                    value: cfg.lastRunAt == null
                        ? 'Jamais'
                        : DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'fr_BE',
                          ).format(cfg.lastRunAt!),
                  ),
                  const Divider(height: 1),
                  InfoRow(
                    label: 'Relances traitées',
                    value: '${cfg.lastRunCount} (dernière exéc.)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SectionHeader(title: 'Paramètres'),
            const SizedBox(height: 14),
            LuxuryCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.champagne,
                    title: Text(
                      'Activer le moteur de relance',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                    subtitle: Text(
                      'Détecte et envoie les relances selon l\'échéance.',
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.champagne,
                    title: Text(
                      'Envoi automatique',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                    subtitle: Text(
                      'Désactivé : détection seule (aucun envoi).',
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                    value: _autoSend,
                    onChanged: _enabled
                        ? (v) => setState(() => _autoSend = v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.champagne,
                    title: Text(
                      'Vérifier au démarrage',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                    subtitle: Text(
                      'Lance une vérification à chaque ouverture de l\'app.',
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                    value: _runOnStartup,
                    onChanged: _enabled
                        ? (v) => setState(() => _runOnStartup = v)
                        : null,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'INTERVALLE DE VÉRIFICATION',
                            style: AppTypography.label.copyWith(
                              fontSize: 10,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _interval,
                            enabled: _enabled,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: 'h',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'DÉLAI MINIMUM ENTRE RELANCES',
                            style: AppTypography.label.copyWith(
                              fontSize: 10,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _minDays,
                            enabled: _enabled,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.white,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: 'j',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Barème d'escalade
            LuxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Barème d\'escalade',
                    style: AppTypography.title.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 10),
                  _thresholdRow(
                    ReminderLevel.first,
                    ReminderService.thresholds[ReminderLevel.first]!,
                  ),
                  _thresholdRow(
                    ReminderLevel.second,
                    ReminderService.thresholds[ReminderLevel.second]!,
                  ),
                  _thresholdRow(
                    ReminderLevel.finalNotice,
                    ReminderService.thresholds[ReminderLevel.finalNotice]!,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GoldButton(
                    label: 'Enregistrer',
                    icon: Icons.save_outlined,
                    fullWidth: true,
                    onPressed: _save,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? null : _runNow,
                    icon: _running
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_outlined, size: 15),
                    label: const Text('EXÉCUTER MAINTENANT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _thresholdRow(ReminderLevel level, int days) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          level == ReminderLevel.finalNotice
              ? Icons.gavel_outlined
              : Icons.mail_outline,
          size: 15,
          color: level == ReminderLevel.finalNotice
              ? AppColors.urgent
              : AppColors.champagne,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(level.label, style: AppTypography.bodyMedium),
        ),
        Text(
          '$days jours de retard',
          style: AppTypography.caption.copyWith(color: AppColors.greyLight),
        ),
      ],
    ),
  );
}
