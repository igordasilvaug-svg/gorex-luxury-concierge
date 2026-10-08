import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/enums.dart';

/// Badge de niveau de confidentialité
class ConfidentialityBadge extends StatelessWidget {
  final ConfidentialityLevel level;
  const ConfidentialityBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level.level >= 4
        ? AppColors.urgent
        : level.level == 3
        ? AppColors.champagne
        : AppColors.grey;
    return StatusPill(
      label: level.label,
      color: color,
      icon: Icons.lock_outline,
    );
  }
}

/// Logo / marque GOREX — logo officiel GOREX LUXURY CONCIERGE (tel quel)
class GorexBrand extends StatelessWidget {
  final bool compact;
  const GorexBrand({super.key, this.compact = false});

  static const String _logoAsset = 'assets/brand/gorex_logo.png';

  @override
  Widget build(BuildContext context) {
    final double h = compact ? 34 : 96;
    return Image.asset(
      _logoAsset,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Étiquette de section (eyebrow)
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppTypography.eyebrow);
}

/// Titre de section avec action optionnelle
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headline),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppTypography.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Carte premium
class LuxuryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool highlighted;
  const LuxuryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              borderColor ??
              (highlighted ? AppColors.champagneDark : AppColors.divider),
          width: highlighted ? 1 : 0.6,
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: card,
    );
  }
}

/// Pastille de statut
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur KPI
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? delta;
  final Color? accent;

  /// Remplace l'affichage texte de [value] (ex. compteur animé).
  final Widget? valueWidget;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.accent,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.champagne;
    return LuxuryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              if (delta != null)
                Text(
                  delta!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          valueWidget ??
              Text(value, style: AppTypography.numberLarge.copyWith(fontSize: 26)),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

/// Badge d'initiales / avatar
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? color;
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.champagne;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.6), width: 0.8),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: c,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Bouton doré principal
class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final bool outlined;
  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: outlined ? AppColors.champagne : AppColors.black,
          ),
          const SizedBox(width: 10),
        ],
        Text(
          label.toUpperCase(),
          style: AppTypography.button.copyWith(
            color: outlined ? AppColors.champagne : AppColors.black,
          ),
        ),
      ],
    );
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: outlined
          ? OutlinedButton(onPressed: onPressed, child: child)
          : ElevatedButton(onPressed: onPressed, child: child),
    );
  }
}

/// Filtre en forme de puce
class FilterChipLux extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  const FilterChipLux({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.champagne.withValues(alpha: 0.14)
              : AppColors.anthracite,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? AppColors.champagneDark : AppColors.divider,
            width: 0.6,
          ),
        ),
        child: Text(
          count != null ? '$label  ·  $count' : label,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.4,
            color: selected ? AppColors.champagne : AppColors.greyLight,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// État vide élégant
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.greyDark),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppTypography.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// Ligne d'information clé/valeur
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label.toUpperCase(),
              style: AppTypography.label.copyWith(
                fontSize: 10,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.offWhite,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Filet doré décoratif
class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.width = 40});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 1.4,
    decoration: const BoxDecoration(gradient: AppColors.goldGradient),
  );
}

/// Message d'erreur
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.urgent.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.urgent.withValues(alpha: 0.4),
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.urgent, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppTypography.bodyMedium)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
