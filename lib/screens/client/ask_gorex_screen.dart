import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/service_catalog.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Écran "Ask Gorex" — expérience extrêmement simple
class AskGorexScreen extends StatefulWidget {
  final bool urgent;
  const AskGorexScreen({super.key, this.urgent = false});

  @override
  State<AskGorexScreen> createState() => _AskGorexScreenState();
}

class _AskGorexScreenState extends State<AskGorexScreen> {
  final _text = TextEditingController();
  final _location = TextEditingController();
  final _budget = TextEditingController();
  ServiceDomain _domain = ServiceDomain.travel;
  UrgencyLevel _urgency = UrgencyLevel.standard;
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.urgent) _urgency = UrgencyLevel.urgent;
  }

  @override
  void dispose() {
    _text.dispose();
    _location.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('Ask Gorex', style: AppTypography.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.urgent)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.urgent.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emergency_outlined,
                        color: AppColors.urgent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Votre concierge et la direction sont alertés immédiatement. L\'heure et l\'intervenant sont enregistrés.',
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              Center(
                child: Column(
                  children: [
                    const GoldDivider(width: 40),
                    const SizedBox(height: 14),
                    Text(
                      'QUE PUIS-JE FAIRE POUR VOUS ?',
                      style: AppTypography.eyebrow,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _text,
                maxLines: 5,
                style: AppTypography.bodyLarge.copyWith(color: AppColors.white),
                decoration: const InputDecoration(
                  hintText:
                      'Ex: Organisez mon arrivée à Bruxelles avec chauffeur, hôtel, restaurant et protection rapprochée.',
                ),
              ),
              const SizedBox(height: 18),
              Text('CATÉGORIE', style: AppTypography.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ServiceDomain.values.map((d) {
                  final sel = _domain == d;
                  return InkWell(
                    onTap: () => setState(() => _domain = d),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.champagne.withValues(alpha: 0.14)
                            : AppColors.anthracite,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: sel ? AppColors.champagne : AppColors.divider,
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            d.icon,
                            size: 14,
                            color: sel ? AppColors.champagne : AppColors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: sel
                                  ? AppColors.champagne
                                  : AppColors.greyLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _location,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'LIEU (optionnel)',
                  prefixIcon: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: AppColors.champagne,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _tapField(
                      icon: Icons.event_outlined,
                      text: '${_date.day}/${_date.month}/${_date.year}',
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tapField(
                      icon: Icons.schedule_outlined,
                      text: _time.format(context),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (t != null) setState(() => _time = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'BUDGET INDICATIF (optionnel)',
                  prefixIcon: Icon(
                    Icons.euro,
                    size: 18,
                    color: AppColors.champagne,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('URGENCE', style: AppTypography.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UrgencyLevel.values.map((u) {
                  final sel = _urgency == u;
                  return InkWell(
                    onTap: () => setState(() => _urgency = u),
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? u.color.withValues(alpha: 0.16)
                            : AppColors.anthracite,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: sel ? u.color : AppColors.divider,
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        u.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: sel ? u.color : AppColors.greyLight,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_domain == ServiceDomain.security) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.champagne.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.champagneDark,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.champagne,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La coordination sécurité sera transmise à GOREX SECURITY.',
                          style: AppTypography.caption.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GoldButton(
                label: _saving ? 'Envoi...' : 'Envoyer à mon concierge',
                icon: Icons.send_outlined,
                fullWidth: true,
                onPressed: _saving ? null : () => _submit(s),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Discretion. Access. Excellence.',
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.greyDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tapField({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.anthracite,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.divider, width: 0.6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.champagne),
            const SizedBox(width: 10),
            Text(
              text,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(AppState s) async {
    final client = s.currentClient;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil client introuvable.')),
      );
      return;
    }
    if (_text.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Décrivez votre demande.')));
      return;
    }
    setState(() => _saving = true);
    final title = _text.text.trim().length > 60
        ? '${_text.text.trim().substring(0, 57)}...'
        : _text.text.trim();
    await s.createRequest(
      clientId: client.id,
      domain: _domain,
      subService: ServiceCatalog.forDomain(_domain).first,
      title: title,
      description: _text.text.trim(),
      date: _date,
      time: _time.format(context),
      location: _location.text.trim().isEmpty
          ? 'À préciser'
          : _location.text.trim(),
      urgency: _urgency,
      budget: double.tryParse(_budget.text) ?? 0,
      securityEscalation: _domain == ServiceDomain.security,
      escalationNote: _domain == ServiceDomain.security
          ? 'Transmis à GOREX SECURITY'
          : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.urgent
              ? 'Demande urgente transmise. Votre concierge est alerté.'
              : 'Votre demande a été transmise à votre concierge.',
        ),
      ),
    );
  }
}
