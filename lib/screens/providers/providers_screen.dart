import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/provider_booking.dart' as model;
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'provider_form_screen.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  ServiceDomain? _filter;

  /// Ouvre le formulaire prestataire (création ou modification).
  Future<void> _openForm([model.Provider? existing]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProviderFormScreen(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = [...s.providers];
    if (_filter != null) list = list.where((p) => p.domain == _filter).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prestataires', style: AppTypography.displayMedium),
                const SizedBox(height: 5),
                Text(
                  '${s.providers.length} partenaires · réseau premium international',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 14),
                // Le bouton est présent même si le carnet est vide : sans lui,
                // le premier prestataire ne pouvait pas être créé.
                GoldButton(
                  label: 'Nouveau prestataire',
                  icon: Icons.add,
                  onPressed: () => _openForm(),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChipLux(
                        label: 'Tous',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      const SizedBox(width: 8),
                      ...ServiceDomain.values.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipLux(
                            label: d.label,
                            selected: _filter == d,
                            onTap: () => setState(
                              () => _filter = _filter == d ? null : d,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'Aucun prestataire',
                    message: s.providers.isEmpty
                        ? 'Ajoutez votre premier partenaire avec le bouton '
                              'ci-dessus.'
                        : 'Aucun prestataire pour ce filtre.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ProviderCard(
                      p: list[i],
                      onTap: () => _openForm(list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final model.Provider p;
  final VoidCallback onTap;
  const _ProviderCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      onTap: () => _showDetail(context, p, onTap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(p.domain.icon, size: 16, color: AppColors.champagne),
              const SizedBox(width: 10),
              Text(
                p.category,
                style: AppTypography.caption.copyWith(
                  color: AppColors.champagne,
                ),
              ),
              const Spacer(),
              _stars(p.trustLevel),
              const SizedBox(width: 10),
              StatusPill(
                label: p.active ? 'Actif' : 'Inactif',
                color: p.active ? AppColors.statusConfirmed : AppColors.grey,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(p.name, style: AppTypography.title),
          const SizedBox(height: 4),
          Text('${p.city}, ${p.country}', style: AppTypography.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.person_outline, p.contactName),
              _meta(Icons.mail_outline, p.contactEmail),
              _meta(
                Icons.percent,
                'Commission ${p.commissionPercent.toStringAsFixed(0)}%',
              ),
              if (p.hasContract)
                _meta(Icons.verified_outlined, 'Contrat signé'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.grey),
      const SizedBox(width: 5),
      Text(t, style: AppTypography.caption.copyWith(fontSize: 10.5)),
    ],
  );

  Widget _stars(int n) => Row(
    children: List.generate(
      5,
      (i) => Icon(
        i < n ? Icons.star : Icons.star_border,
        size: 12,
        color: AppColors.champagne,
      ),
    ),
  );

  /// Ouvre la fiche détaillée puis, si l'utilisateur demande la
  /// modification, ouvre le formulaire APRÈS la fermeture effective de la
  /// feuille.
  ///
  /// La version précédente enchaînait `Navigator.pop()` puis l'ouverture du
  /// formulaire dans le même frame : l'écran de saisie pouvait être avalé par
  /// l'animation de fermeture et le bouton semblait sans effet. On attend ici
  /// la fin de la feuille, qui renvoie la décision de l'utilisateur.
  Future<void> _showDetail(
    BuildContext context,
    model.Provider p,
    VoidCallback onEdit,
  ) async {
    final wantsEdit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contenu défilant…
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(p.name, style: AppTypography.headline),
                    const SizedBox(height: 4),
                    Text(
                      '${p.category} · ${p.city}, ${p.country}',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 18),
                    LuxuryCard(
                      child: Column(
                        children: [
                          InfoRow(label: 'Contact', value: p.contactName),
                          const Divider(height: 1),
                          InfoRow(label: 'E-mail', value: p.contactEmail),
                          const Divider(height: 1),
                          InfoRow(label: 'Téléphone', value: p.contactPhone),
                          const Divider(height: 1),
                          InfoRow(
                            label: 'Tarif indicatif',
                            value: NumberFormat.currency(
                              locale: 'fr_BE',
                              symbol: '€',
                              decimalDigits: 0,
                            ).format(p.rate),
                          ),
                          const Divider(height: 1),
                          InfoRow(
                            label: 'Commission',
                            value: '${p.commissionPercent.toStringAsFixed(0)}%',
                          ),
                          const Divider(height: 1),
                          InfoRow(
                            label: 'Confiance',
                            value: '${p.trustLevel}/5',
                          ),
                          const Divider(height: 1),
                          InfoRow(
                            label: 'Contrat',
                            value: p.hasContract ? 'Signé' : 'En cours',
                          ),
                        ],
                      ),
                    ),
                    if (p.documentNames.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('DOCUMENTS', style: AppTypography.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.documentNames
                            .map(
                              (d) => StatusPill(
                                label: d,
                                color: AppColors.greyLight,
                                icon: Icons.description_outlined,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (p.internalNotes != null) ...[
                      const SizedBox(height: 16),
                      Text('NOTES INTERNES', style: AppTypography.label),
                      const SizedBox(height: 6),
                      Text(p.internalNotes!, style: AppTypography.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            // …et pied de feuille FIXE : le bouton reste atteignable même
            // sur un écran court, quel que soit le volume d'informations.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
              child: GoldButton(
                label: 'Modifier ce prestataire',
                icon: Icons.edit_outlined,
                fullWidth: true,
                // On ferme en signalant l'intention ; l'ouverture du
                // formulaire est faite par l'appelant, une fois la feuille
                // réellement refermée.
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ),
    );

    if (wantsEdit == true) onEdit();
  }
}
