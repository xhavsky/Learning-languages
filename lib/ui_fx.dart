import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// `flutter test --dart-define=SCREENSHOT_MODE=true` — bez animacji tła.
bool get kScreenshotMode {
  if (_screenshotModeOverride != null) return _screenshotModeOverride!;
  return const bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false) ||
      Platform.environment['SCREENSHOT_MODE'] == '1' ||
      Platform.environment['SCREENSHOT_MODE'] == 'true';
}

bool? _screenshotModeOverride;

/// Włączane z testów screenshotów.
void enableScreenshotModeForTests() => _screenshotModeOverride = true;

/// Czytelna ikona w AppBarze: jasne tło + mocniejszy kontrast.
class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bright = Theme.of(context).brightness == Brightness.light;
    final bg = active
        ? scheme.primary
        : scheme.primaryContainer.withValues(alpha: bright ? 0.95 : 0.88);
    final fg = active ? scheme.onPrimary : scheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: scheme.primary.withValues(alpha: active ? 0 : 0.35),
              width: 1.5,
            ),
          ),
          elevation: bright ? 1.5 : 0,
          shadowColor: scheme.primary.withValues(alpha: 0.35),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 26, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// Soft page backdrop with palette gradient + floating orbs.
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
    final accent = palette.accent;
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
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -0.9),
                  radius: 1.15,
                  colors: [
                    seed.withValues(alpha: bright ? 0.22 : 0.26),
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
                    accent.withValues(alpha: bright ? 0.16 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: kScreenshotMode
                ? const SizedBox.shrink()
                : _FloatingOrbs(seed: seed, accent: accent, bright: bright),
          ),
          child,
        ],
      ),
    );
  }
}

/// Delikatne „baloniki” w tle — apka żyje, nie przeszkadza.
class _FloatingOrbs extends StatefulWidget {
  const _FloatingOrbs({
    required this.seed,
    required this.accent,
    required this.bright,
  });

  final Color seed;
  final Color accent;
  final bool bright;

  @override
  State<_FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<_FloatingOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * math.pi * 2;
        return CustomPaint(
          painter: _OrbsPainter(
            t: t,
            seed: widget.seed,
            accent: widget.accent,
            bright: widget.bright,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OrbsPainter extends CustomPainter {
  _OrbsPainter({
    required this.t,
    required this.seed,
    required this.accent,
    required this.bright,
  });

  final double t;
  final Color seed;
  final Color accent;
  final bool bright;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final specs = <(Alignment, double, Color)>[
      (const Alignment(-0.7, -0.55), 70, seed),
      (const Alignment(0.75, -0.2), 55, accent),
      (const Alignment(-0.35, 0.7), 90, seed),
      (const Alignment(0.55, 0.55), 48, accent),
    ];
    for (var i = 0; i < specs.length; i++) {
      final (align, baseR, color) = specs[i];
      final wobble = math.sin(t + i * 1.3) * 12;
      final r = baseR + math.cos(t * 0.8 + i) * 6;
      final center = Offset(
        (align.x + 1) / 2 * size.width + wobble,
        (align.y + 1) / 2 * size.height + math.cos(t + i) * 10,
      );
      paint.color = color.withValues(alpha: bright ? 0.11 : 0.14);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter old) =>
      old.t != t || old.seed != seed || old.accent != accent;
}

/// Pasek misji dnia + streak — na górze ekranu nauki.
class DailyMissionBanner extends StatelessWidget {
  const DailyMissionBanner({
    super.key,
    required this.wordsToday,
    required this.dailyGoal,
    required this.streakDays,
    required this.palette,
    required this.title,
    required this.subtitle,
  });

  final int wordsToday;
  final int dailyGoal;
  final int streakDays;
  final AppPalette palette;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (wordsToday / dailyGoal).clamp(0.0, 1.0);
    final done = wordsToday >= dailyGoal;
    return SoftPanel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ),
              ),
              _StreakBadge(days: streakDays, accent: palette.accent),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done
                          ? 'Misja dnia zaliczona!'
                          : 'Misja dnia: $wordsToday / $dailyGoal słówek',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: done ? palette.seed : scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SheenProgressBar(
                      value: progress,
                      minHeight: 12,
                      backgroundColor:
                          scheme.primaryContainer.withValues(alpha: 0.45),
                      color: done ? palette.accent : scheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _SessionRing(
                progress: progress,
                accent: done ? palette.accent : scheme.primary,
                label: done ? '✓' : '$wordsToday',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days, required this.accent});

  final int days;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.95),
              accent.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 4),
            Text(
              '$days',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRing extends StatelessWidget {
  const _SessionRing({
    required this.progress,
    required this.accent,
    required this.label,
  });

  final double progress;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: accent.withValues(alpha: 0.18),
              color: accent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: label.length > 2 ? 14 : 16,
              color: accent,
            ),
          ),
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
    final radiusGeom = BorderRadius.circular(radius);
    // Material nad ListTile/ExpansionTile — bez assertu „ink splash invisible”.
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radiusGeom,
        boxShadow: softShadows(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radiusGeom,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: bright ? 0.90 : 0.74),
            borderRadius: radiusGeom,
            border: Border.all(
              color: scheme.primary.withValues(alpha: bright ? 0.18 : 0.28),
              width: 1.4,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: bright ? 0.96 : 0.80),
                scheme.primaryContainer.withValues(alpha: bright ? 0.28 : 0.18),
                scheme.tertiaryContainer.withValues(alpha: bright ? 0.12 : 0.10),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
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

/// Równa siatka akcji (2 kolumny) — symetryczne kafelki na telefonie.
class ActionGrid extends StatelessWidget {
  const ActionGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 10,
    this.childAspectRatio = 2.35,
  });

  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// Kafelek w [ActionGrid] — pełna szerokość komórki, równa wysokość.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: selected ? scheme.primaryContainer : null,
      ),
    );
  }
}

/// Dwa równe przyciski w jednym wierszu (50/50).
class EqualButtonRow extends StatelessWidget {
  const EqualButtonRow({
    super.key,
    required this.left,
    required this.right,
    this.gap = 10,
  });

  final Widget left;
  final Widget right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }
}

// ─── Shimmer ───────────────────────────────────────────────────────────────

/// Animowany „połysk” po szkielecie / pasku — w SCREENSHOT_MODE bez ruchu.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    if (!kScreenshotMode) {
      _ctrl.repeat();
    } else {
      _ctrl.value = 0.45;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bright = Theme.of(context).brightness == Brightness.light;
    final base = scheme.onSurface.withValues(alpha: bright ? 0.10 : 0.16);
    final hilite = scheme.onSurface.withValues(alpha: bright ? 0.28 : 0.38);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.2 + 2.4 * t, 0),
              end: Alignment(-0.2 + 2.4 * t, 0),
              colors: [base, hilite, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Kość szkieletu (prostokąt / pill).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Pasek postępu z delikatnym połyskiem na wypełnieniu.
class SheenProgressBar extends StatelessWidget {
  const SheenProgressBar({
    super.key,
    required this.value,
    this.minHeight = 12,
    this.color,
    this.backgroundColor,
  });

  final double value;
  final double minHeight;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value.clamp(0.0, 1.0);
    final fill = color ?? scheme.primary;
    final track =
        backgroundColor ?? scheme.primaryContainer.withValues(alpha: 0.45);

    return ClipRRect(
      borderRadius: BorderRadius.circular(minHeight),
      child: SizedBox(
        height: minHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: v > 0.02 && v < 0.999 && !kScreenshotMode
                  ? Shimmer(
                      duration: const Duration(milliseconds: 1800),
                      child: ColoredBox(color: fill),
                    )
                  : ColoredBox(color: fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// Szkielet startu aplikacji (zamiast gołego spinnera).
class AppBootShimmer extends StatelessWidget {
  const AppBootShimmer({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Shimmer(
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SoftPanel(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const ShimmerBox(width: 72, height: 28, radius: 14),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: ShimmerBox(height: 18, radius: 8),
                              ),
                              const SizedBox(width: 10),
                              const ShimmerBox(width: 40, height: 28, radius: 14),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const ShimmerBox(height: 12, radius: 8),
                          const SizedBox(height: 10),
                          const ShimmerBox(height: 10, width: 160, radius: 8),
                        ],
                      ),
                    ),
                    SoftPanel(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerBox(height: 14, width: 200, radius: 8),
                          const SizedBox(height: 12),
                          const ShimmerBox(height: 36, width: 120, radius: 10),
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              Expanded(child: ShimmerBox(height: 48, radius: 14)),
                              SizedBox(width: 10),
                              Expanded(child: ShimmerBox(height: 48, radius: 14)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const ShimmerBox(height: 52, radius: 16),
                          const SizedBox(height: 12),
                          const ShimmerBox(height: 52, radius: 16),
                        ],
                      ),
                    ),
                    SoftPanel(
                      child: Column(
                        children: const [
                          ShimmerBox(height: 16, width: 180, radius: 8),
                          SizedBox(height: 12),
                          ShimmerBox(height: 14, radius: 8),
                          SizedBox(height: 8),
                          ShimmerBox(height: 14, width: 220, radius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bańka „AI pisze…” w czacie.
class ChatReplyShimmer extends StatelessWidget {
  const ChatReplyShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Shimmer(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14, radius: 8),
                SizedBox(height: 8),
                ShimmerBox(height: 14, width: 130, radius: 8),
                SizedBox(height: 8),
                ShimmerBox(height: 14, width: 88, radius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder podglądu 3D / CEF.
class ViewerShimmer extends StatelessWidget {
  const ViewerShimmer({super.key, this.backgroundColor});

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
    return ColoredBox(
      color: bg,
      child: Center(
        child: Shimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(
                width: 120,
                height: 120,
                radius: 60,
              ),
              const SizedBox(height: 16),
              const ShimmerBox(width: 140, height: 12, radius: 6),
              const SizedBox(height: 8),
              const ShimmerBox(width: 90, height: 10, radius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
