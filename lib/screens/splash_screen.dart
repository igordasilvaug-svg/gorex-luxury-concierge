import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// Séquence d'ouverture GOREX — révélation du monogramme, filet doré
/// puis signature de la maison. Élégance cinématographique et discrète.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  late final Animation<double> _markScale;
  late final Animation<double> _markOpacity;
  late final Animation<double> _lineWidth;
  late final Animation<double> _sigOpacity;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _markScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic)),
    );
    _markOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _lineWidth = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic)),
    );
    _sigOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );
    _glow = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
    );

    _c.forward();
    _c.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) widget.onFinished();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo officiel GOREX LUXURY CONCIERGE (tel quel)
                Opacity(
                  opacity: _markOpacity.value,
                  child: Transform.scale(
                    scale: _markScale.value,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.champagne.withValues(
                              alpha: 0.18 * _glow.value,
                            ),
                            blurRadius: 46,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/brand/gorex_logo.png',
                        width: 236,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                // Filet doré qui se déploie
                Container(
                  width: 220 * _lineWidth.value,
                  height: 1.2,
                  decoration: const BoxDecoration(
                    gradient: AppColors.goldGradient,
                  ),
                ),
                const SizedBox(height: 90),
                Opacity(
                  opacity: _sigOpacity.value,
                  child: Column(
                    children: [
                      Text(
                        'DISCRETION. ACCESS. EXCELLENCE.',
                        style: AppTypography.eyebrow.copyWith(
                          fontSize: 9,
                          letterSpacing: 3.4,
                          color: AppColors.champagneDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gorex Group — Belgique',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.greyDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
