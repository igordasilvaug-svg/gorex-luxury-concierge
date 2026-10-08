import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../state/app_state.dart';

/// Sélecteur de langue compact (FR / NL / EN) — segmenté, style luxe.
/// Lit et écrit `AppState.language` (persisté).
class LanguageSelector extends StatelessWidget {
  final bool dense;
  const LanguageSelector({super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: EdgeInsets.all(dense ? 2 : 3),
      decoration: BoxDecoration(
        color: AppColors.blackSoft,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.divider, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: L10n.supported.map((code) {
          final selected = state.language == code;
          return GestureDetector(
            onTap: () => state.setLanguage(code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 8 : 12,
                vertical: dense ? 4 : 6,
              ),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.goldGradient : null,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                L10n.shortLabels[code] ?? code.toUpperCase(),
                style: AppTypography.label.copyWith(
                  fontSize: dense ? 9.5 : 10.5,
                  color: selected ? AppColors.black : AppColors.grey,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Version « liste » pour les écrans de réglages / profil.
class LanguageTileList extends StatelessWidget {
  const LanguageTileList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      children: L10n.supported.map((code) {
        final selected = state.language == code;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Text(
            L10n.flags[code] ?? '🏳️',
            style: const TextStyle(fontSize: 18),
          ),
          title: Text(
            L10n.name(code),
            style: AppTypography.bodyMedium.copyWith(
              color: selected ? AppColors.champagne : AppColors.greyLight,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check, size: 17, color: AppColors.champagne)
              : null,
          onTap: () => state.setLanguage(code),
        );
      }).toList(),
    );
  }
}
