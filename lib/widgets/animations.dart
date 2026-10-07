import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

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
