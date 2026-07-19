import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Tytuł sekcji z delikatną kreską — spójne nagłówki w całej apce.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft page backdrop with palette gradient + subtle vignette.
class GradientScaffoldBody extends StatelessWidget {
  const GradientScaffoldBody({
    super.key,
    required this.palette,
    required this.child,
  });

  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bright = Theme.of(context).brightness == Brightness.light;
    final g = palette.gradient(bright);
    final seed = palette.seed;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Delikatne „światło” w rogu — mniej płasko, nadal spójne z paletą.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.9),
                  radius: 1.15,
                  colors: [
                    seed.withValues(alpha: bright ? 0.18 : 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, 0.85),
                  radius: 0.95,
                  colors: [
                    seed.withValues(alpha: bright ? 0.10 : 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Elevated surface with soft shadow (no hard Material card chrome).
class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bright = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: bright ? 0.90 : 0.74),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: bright ? 0.95 : 0.78),
            scheme.primaryContainer.withValues(alpha: bright ? 0.22 : 0.14),
          ],
        ),
        boxShadow: softShadows(context),
      ),
      child: child,
    );
  }
}

List<BoxShadow> softShadows(BuildContext context, {double lift = 1}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
      blurRadius: 18 * lift,
      offset: Offset(0, 8 * lift),
    ),
    BoxShadow(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: dark ? 0.12 : 0.08),
      blurRadius: 28 * lift,
      offset: Offset(0, 4 * lift),
    ),
  ];
}

enum FeedbackKind { success, fail, hint, info }

/// Slide-in toast + optional burst / shake driven by [kind].
class AnimatedFeedbackBanner extends StatelessWidget {
  const AnimatedFeedbackBanner({
    super.key,
    required this.message,
    required this.kind,
    required this.visible,
    this.onDismiss,
  });

  final String message;
  final FeedbackKind kind;
  final bool visible;
  final VoidCallback? onDismiss;

  Color _tint(ColorScheme s) => switch (kind) {
        FeedbackKind.success => const Color(0xFF2E7D32),
        FeedbackKind.fail => const Color(0xFFC62828),
        FeedbackKind.hint => s.primary,
        FeedbackKind.info => s.secondary,
      };

  IconData get _icon => switch (kind) {
        FeedbackKind.success => Icons.celebration_rounded,
        FeedbackKind.fail => Icons.sentiment_dissatisfied_rounded,
        FeedbackKind.hint => Icons.lightbulb_outline_rounded,
        FeedbackKind.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final tint = _tint(Theme.of(context).colorScheme);
    return AnimatedSlide(
      duration: const Duration(milliseconds: 380),
      curve: visible ? Curves.easeOutBack : Curves.easeIn,
      offset: visible ? Offset.zero : const Offset(0, -0.35),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: visible ? 1 : 0,
        child: SoftPanel(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey('$message-$kind'),
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        tint.withValues(alpha: 0.9),
                        tint.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: tint,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal shake for wrong answers.
class Shake extends StatelessWidget {
  const Shake({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = animation.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: child,
    );
  }
}

/// Brief pop + glow when answer is correct.
class SuccessPulse extends StatelessWidget {
  const SuccessPulse({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = Curves.easeOut.transform(animation.value.clamp(0.0, 1.0));
        final scale = 1 + 0.08 * math.sin(t * math.pi);
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withValues(alpha: 0.35 * (1 - t)),
                  blurRadius: 24 * (1 - t + 0.2),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Lightweight confetti dots for success (no packages).
class SuccessBurst extends StatelessWidget {
  const SuccessBurst({
    super.key,
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          if (animation.value <= 0 || animation.value >= 1) {
            return const SizedBox.shrink();
          }
          final t = animation.value;
          return CustomPaint(
            painter: _BurstPainter(progress: t),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress});

  final double progress;

  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 14; i++) {
      final angle = (i / 14) * math.pi * 2 + progress;
      final dist = 40 + progress * (90 + (i % 3) * 28);
      final pos = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - progress);
      canvas.drawCircle(pos, 4 + (i % 3).toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Prompt word with fade/slide when the card changes.
class AnimatedPromptWord extends StatelessWidget {
  const AnimatedPromptWord({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// Gradient-filled primary action button with shadow.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.palette,
  });

  final VoidCallback? onPressed;
  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final bright = Theme.of(context).brightness == Brightness.light;
    final colors = palette.buttonGradient(bright);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: colors),
            boxShadow: softShadows(context, lift: 0.7),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
