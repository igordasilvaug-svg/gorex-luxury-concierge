import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'common.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Boîte à outils d'animations GOREX — élégance discrète, jamais ostentatoire.
/// ─────────────────────────────────────────────────────────────────────────

/// Fait apparaître son enfant avec un léger glissement vertical + fondu.
/// [delay] permet de créer un effet d'entrée en cascade.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 650),
    this.offset = 18,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.offset / 100),
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Compteur qui « roule » jusqu'à sa valeur cible, avec préfixe/suffixe.
/// Idéal pour les KPI financiers (chiffre d'affaires, marge...).
class GoldCountUp extends StatelessWidget {
  final num value;
  final String Function(num) formatter;
  final Duration duration;
  final TextStyle? style;

  const GoldCountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 1100),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        formatter(v.round()),
        style: style,
      ),
    );
  }
}

/// Filet doré qui se déploie de gauche à droite (effet « signature »).
class GoldLineGrow extends StatelessWidget {
  final double width;
  final Duration delay;
  final double thickness;

  const GoldLineGrow({
    super.key,
    this.width = 60,
    this.delay = Duration.zero,
    this.thickness = 1.4,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: width),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, w, _) => Container(
        width: w,
        height: thickness,
        decoration: const BoxDecoration(gradient: AppColors.goldGradient),
      ),
    );
  }
}

/// Transition de page « fondu doré » — fondu + micro-glissement vertical.
/// Donne à la navigation un effet de rideau qui se lève, sobre et fluide.
class GoldPageTransitionsBuilder extends PageTransitionsBuilder {
  const GoldPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Halo pulsant discret — attire l'œil sans jamais crier.
/// Idéal pour le bouton « Demande urgente ».
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool enabled;
  final Duration period;

  const PulseGlow({
    super.key,
    required this.child,
    this.color = AppColors.urgent,
    this.enabled = true,
    this.period = const Duration(milliseconds: 1900),
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.10 + 0.22 * t),
                blurRadius: 10 + 14 * t,
                spreadRadius: 0.5 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Avatar à anneau doré en rotation lente — signature visuelle discrète.
class AnimatedRingAvatar extends StatefulWidget {
  final String initials;
  final double size;
  final Color color;
  final Duration period;

  const AnimatedRingAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.color = AppColors.champagne,
    this.period = const Duration(seconds: 9),
  });

  @override
  State<AnimatedRingAvatar> createState() => _AnimatedRingAvatarState();
}

class _AnimatedRingAvatarState extends State<AnimatedRingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.size + 7;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _c,
            child: CustomPaint(
              size: Size(outer, outer),
              painter: _RingPainter(color: widget.color),
            ),
          ),
          InitialsAvatar(
            initials: widget.initials,
            size: widget.size,
            color: widget.color,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width / 2) - 1.4;
    // Arc doré ouvert (≈ 290°) avec dégradé tournant
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      5.06, // ≈ 290°
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.color != color;
}

/// Bloc « squelette » animé (shimmer) — à afficher pendant un chargement.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.radius ?? BorderRadius.circular(3);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 + 2 * (1 - t), 0),
              colors: const [
                AppColors.anthracite,
                AppColors.anthraciteLight,
                AppColors.anthracite,
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// Liste de chargement type « carte » avec en-tête + lignes squelettes.
class ListSkeleton extends StatelessWidget {
  final int items;
  const ListSkeleton({super.key, this.items = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: items,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, _) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.divider, width: 0.6),
        ),
        child: Row(
          children: [
            const ShimmerBox(width: 44, height: 44, radius: BorderRadius.all(Radius.circular(22))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 160, height: 13),
                  SizedBox(height: 9),
                  ShimmerBox(width: 220, height: 10),
                  SizedBox(height: 9),
                  ShimmerBox(width: 120, height: 10),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ShimmerBox(width: 58, height: 20),
          ],
        ),
      ),
    );
  }
}

/// Squelette de tableau de bord (grille de KPI + cartes).
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 300, height: 26),
            const SizedBox(height: 12),
            const ShimmerBox(width: 220, height: 12),
            const SizedBox(height: 10),
            const ShimmerBox(width: 60, height: 2),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: List.generate(
                6,
                (_) => Container(
                  width: 210,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.divider, width: 0.6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 20, height: 16),
                      SizedBox(height: 16),
                      ShimmerBox(width: 110, height: 24),
                      SizedBox(height: 10),
                      ShimmerBox(width: 90, height: 9),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Balayage lumineux (« shimmer ») très discret sur une surface dorée.
/// Purement décoratif — respecte le thème sombre de la marque.
class GoldShimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const GoldShimmer({super.key, required this.child, this.enabled = true});

  @override
  State<GoldShimmer> createState() => _GoldShimmerState();
}

class _GoldShimmerState extends State<GoldShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.enabled) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final t = _c.value;
            return LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 + 2 * (1 - t), 0),
              colors: const [
                Colors.transparent,
                Color(0x33D8BC85),
                Color(0x66D8BC85),
                Color(0x33D8BC85),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
