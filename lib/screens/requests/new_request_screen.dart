import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/service_catalog.dart';
import '../../models/enums.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';

class NewRequestScreen extends StatefulWidget {
  final bool urgentMode;
  const NewRequestScreen({super.key, this.urgentMode = false});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _budget = TextEditingController();

  ServiceDomain _domain = ServiceDomain.travel;
  String? _subService;
  UrgencyLevel _urgency = UrgencyLevel.standard;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  String? _clientId;
  bool _securityEscalation = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.urgentMode) _urgency = UrgencyLevel.urgent;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isClient = s.isClient;
    _clientId ??=
        s.currentClient?.id ??
        (s.clients.isNotEmpty ? s.clients.first.id : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.urgentMode ? 'Demande urgente' : 'Nouvelle demande',
          style: AppTypography.title,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.urgentMode)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.urgent.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.urgent.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.priority_high,
                          color: AppColors.urgent,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Demande prioritaire — votre concierge et la direction sont alertés immédiatement.',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isClient) ...[
                  _label('CLIENT'),
                  _clientPicker(s),
                  const SizedBox(height: 16),
                ],
                _label('DOMAINE DE SERVICE'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ServiceDomain.values.map((d) {
                    final sel = _domain == d;
                    return InkWell(
                      onTap: () => setState(() {
                        _domain = d;
                        _subService = null;
                      }),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.champagne.withValues(alpha: 0.14)
                              : AppColors.anthracite,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: sel
                                ? AppColors.champagne
                                : AppColors.divider,
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              d.icon,
                              size: 15,
                              color: sel ? AppColors.champagne : AppColors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              d.label,
                              style: AppTypography.bodyMedium.copyWith(
                                color: sel
                                    ? AppColors.champagne
                                    : AppColors.greyLight,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _label('PRESTATION'),
                DropdownButtonFormField<String>(
                  initialValue: _subService,
                  dropdownColor: AppColors.surfaceElevated,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Sélectionner une prestation',
                  ),
                  items: ServiceCatalog.forDomain(_domain)
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _subService = v),
                ),
                const SizedBox(height: 16),
                _label('TITRE DE LA DEMANDE'),
                TextField(
                  controller: _title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ex: Arrivée à Bruxelles — jet, chauffeur, hôtel',
                  ),
                ),
                const SizedBox(height: 16),
                _label('DESCRIPTION'),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Décrivez votre demande en détail...',
                  ),
                ),
                const SizedBox(height: 16),
                _label('LOCALISATION'),
                TextField(
                  controller: _location,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: 'Ville, pays'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('DATE'),
                          InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.anthracite,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.divider,
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_outlined,
                                    size: 16,
                                    color: AppColors.champagne,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${_date.day}/${_date.month}/${_date.year}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('HEURE'),
                          InkWell(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.anthracite,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.divider,
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_outlined,
                                    size: 16,
                                    color: AppColors.champagne,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _time.format(context),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label('NIVEAU D\'URGENCE'),
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
                const SizedBox(height: 16),
                _label('BUDGET INDICATIF (€)'),
                TextField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(hintText: '0'),
                ),
                if (_domain == ServiceDomain.security ||
                    _domain == ServiceDomain.medical) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _securityEscalation,
                    onChanged: (v) =>
                        setState(() => _securityEscalation = v ?? false),
                    activeColor: AppColors.champagne,
                    checkColor: AppColors.black,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Transmettre à GOREX SECURITY',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.offWhite,
                      ),
                    ),
                    subtitle: Text(
                      'La coordination sécurité sera gérée par la division GOREX SECURITY.',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                GoldButton(
                  label: _saving ? 'Envoi...' : 'Soumettre la demande',
                  icon: Icons.send_outlined,
                  fullWidth: true,
                  onPressed: _saving ? null : () => _submit(s),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: AppTypography.label),
  );

  Widget _clientPicker(AppState s) {
    return DropdownButtonFormField<String>(
      initialValue: _clientId,
      dropdownColor: AppColors.surfaceElevated,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
      decoration: const InputDecoration(hintText: 'Sélectionner un client'),
      items: s.clients
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text('${c.fullName} — ${c.code}'),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _clientId = v),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit(AppState s) async {
    if (_title.text.trim().isEmpty || _clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le titre et le client.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await s.createRequest(
      clientId: _clientId!,
      domain: _domain,
      subService: _subService ?? ServiceCatalog.forDomain(_domain).first,
      title: _title.text.trim(),
      description: _description.text.trim(),
      date: _date,
      time: _time.format(context),
      location: _location.text.trim().isEmpty
          ? 'À préciser'
          : _location.text.trim(),
      urgency: _urgency,
      budget: double.tryParse(_budget.text) ?? 0,
      securityEscalation: _securityEscalation,
      escalationNote: _securityEscalation ? 'Transmis à GOREX SECURITY' : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demande transmise à votre concierge.')),
    );
  }
}
