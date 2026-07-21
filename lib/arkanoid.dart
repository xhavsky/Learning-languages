import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'theme.dart';

const _prefsHighScore = 'arkanoid_high_score';

Future<void> openArkanoid(
  BuildContext context, {
  required AppPalette palette,
  required UiLang uiLang,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ArkanoidPage(palette: palette, uiLang: uiLang),
    ),
  );
}

class ArkanoidPage extends StatefulWidget {
  const ArkanoidPage({
    super.key,
    required this.palette,
    required this.uiLang,
  });

  final AppPalette palette;
  final UiLang uiLang;

  @override
  State<ArkanoidPage> createState() => _ArkanoidPageState();
}

enum _Phase { ready, playing, paused, won, lost }

class _Brick {
  _Brick({
    required this.rect,
    required this.color,
    required this.points,
  });

  Rect rect;
  Color color;
  int points;
  bool alive = true;
}

class _ArkanoidPageState extends State<ArkanoidPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final FocusNode _focus;

  _Phase _phase = _Phase.ready;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  int _level = 1;
  bool _newRecord = false;

  Size _field = Size.zero;
  Offset _ball = Offset.zero;
  Offset _vel = Offset.zero;
  double _paddleX = 0;
  double _paddleW = 96;
  double _ballR = 8;
  final List<_Brick> _bricks = [];

  bool _leftHeld = false;
  bool _rightHeld = false;

  L10n get l10n => L10n(widget.uiLang);

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _enterFullscreen();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _exitFullscreen();
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _highScore = prefs.getInt(_prefsHighScore) ?? 0);
  }

  Future<void> _maybeSaveHighScore() async {
    if (_score <= _highScore) return;
    _highScore = _score;
    _newRecord = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsHighScore, _highScore);
  }

  void _layoutField(Size size) {
    if (size == _field || size.isEmpty) return;
    final first = _field == Size.zero;
    _field = size;
    _paddleW = (size.width * 0.18).clamp(72.0, 140.0);
    _ballR = (size.shortestSide * 0.018).clamp(6.0, 10.0);
    if (first) {
      _resetBallAndPaddle(serve: false);
      _buildBricks();
    } else {
      _paddleX = _paddleX.clamp(0.0, _field.width - _paddleW);
    }
  }

  void _resetBallAndPaddle({required bool serve}) {
    _paddleX = _field.width / 2 - _paddleW / 2;
    _ball = Offset(_field.width / 2, _field.height - 56 - _ballR);
    if (serve) {
      final angle = -math.pi / 2 + (math.Random().nextDouble() - 0.5) * 0.7;
      final speed = 260 + _level * 28.0;
      _vel = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
    } else {
      _vel = Offset.zero;
    }
  }

  void _buildBricks() {
    _bricks.clear();
    final cols = 8;
    final rows = (4 + (_level - 1)).clamp(4, 7);
    final gap = 6.0;
    final top = 52.0;
    final side = 16.0;
    final brickW = (_field.width - side * 2 - gap * (cols - 1)) / cols;
    final brickH = (_field.height * 0.045).clamp(18.0, 28.0);
    final palette = widget.palette;
    final colors = [
      palette.seed,
      palette.accent,
      palette.buttonGradient(true).first,
      palette.buttonGradient(true).last,
      Color.lerp(palette.seed, palette.accent, 0.5)!,
    ];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final pts = (rows - r) * 10;
        _bricks.add(
          _Brick(
            rect: Rect.fromLTWH(
              side + c * (brickW + gap),
              top + r * (brickH + gap),
              brickW,
              brickH,
            ),
            color: colors[r % colors.length],
            points: pts,
          ),
        );
      }
    }
  }

  void _startGame({bool nextLevel = false}) {
    if (nextLevel) {
      _level++;
    } else {
      _score = 0;
      _lives = 3;
      _level = 1;
      _newRecord = false;
    }
    _buildBricks();
    _resetBallAndPaddle(serve: true);
    _phase = _Phase.playing;
    _ticker.repeat();
    setState(() {});
  }

  void _pauseToggle() {
    if (_phase == _Phase.playing) {
      _phase = _Phase.paused;
      _ticker.stop();
    } else if (_phase == _Phase.paused) {
      _phase = _Phase.playing;
      _ticker.repeat();
    }
    setState(() {});
  }

  void _tick() {
    if (_phase != _Phase.playing || _field.isEmpty) return;
    // ~dt from controller — treat each frame as ~1/60 when repeating
    const dt = 1 / 60;

    // Paddle keyboard
    final paddleSpeed = _field.width * 0.9;
    if (_leftHeld) _paddleX -= paddleSpeed * dt;
    if (_rightHeld) _paddleX += paddleSpeed * dt;
    _paddleX = _paddleX.clamp(0.0, _field.width - _paddleW);

    var bx = _ball.dx + _vel.dx * dt;
    var by = _ball.dy + _vel.dy * dt;
    var vx = _vel.dx;
    var vy = _vel.dy;

    // Walls
    if (bx - _ballR <= 0) {
      bx = _ballR;
      vx = vx.abs();
    } else if (bx + _ballR >= _field.width) {
      bx = _field.width - _ballR;
      vx = -vx.abs();
    }
    if (by - _ballR <= 0) {
      by = _ballR;
      vy = vy.abs();
    }

    // Paddle
    final paddleTop = _field.height - 40;
    final paddleRect = Rect.fromLTWH(_paddleX, paddleTop, _paddleW, 14);
    final ballRect = Rect.fromCircle(center: Offset(bx, by), radius: _ballR);
    if (vy > 0 && ballRect.overlaps(paddleRect)) {
      by = paddleTop - _ballR;
      final hit = ((bx - _paddleX) / _paddleW).clamp(0.0, 1.0);
      final angle = -math.pi * 0.85 + hit * math.pi * 0.7;
      final speed = math.sqrt(vx * vx + vy * vy).clamp(240.0, 520.0);
      vx = math.cos(angle) * speed;
      vy = math.sin(angle) * speed;
    }

    // Bricks
    for (final b in _bricks) {
      if (!b.alive) continue;
      if (!ballRect.overlaps(b.rect)) continue;
      b.alive = false;
      _score += b.points;
      // Bounce from nearest side
      final overlapL = (bx + _ballR) - b.rect.left;
      final overlapR = b.rect.right - (bx - _ballR);
      final overlapT = (by + _ballR) - b.rect.top;
      final overlapB = b.rect.bottom - (by - _ballR);
      final minX = math.min(overlapL, overlapR);
      final minY = math.min(overlapT, overlapB);
      if (minX < minY) {
        vx = -vx;
        bx += overlapL < overlapR ? -overlapL : overlapR;
      } else {
        vy = -vy;
        by += overlapT < overlapB ? -overlapT : overlapB;
      }
      break;
    }

    // Lost ball
    if (by - _ballR > _field.height) {
      _lives--;
      if (_lives <= 0) {
        _phase = _Phase.lost;
        _ticker.stop();
        _maybeSaveHighScore();
      } else {
        _resetBallAndPaddle(serve: true);
      }
      setState(() {});
      return;
    }

    // Cleared level
    if (_bricks.every((b) => !b.alive)) {
      _phase = _Phase.won;
      _ticker.stop();
      _score += 100 * _level;
      _maybeSaveHighScore();
      setState(() {});
      return;
    }

    _ball = Offset(bx, by);
    _vel = Offset(vx, vy);
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;
    final key = event.logicalKey;

    void setDir(bool left, bool right) {
      if (isDown) {
        if (left) _leftHeld = true;
        if (right) _rightHeld = true;
      } else if (isUp) {
        if (left) _leftHeld = false;
        if (right) _rightHeld = false;
      }
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      setDir(true, false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      setDir(false, true);
      return KeyEventResult.handled;
    }
    if (isDown && key == LogicalKeyboardKey.space) {
      if (_phase == _Phase.ready || _phase == _Phase.lost) {
        _startGame();
      } else if (_phase == _Phase.won) {
        _startGame(nextLevel: true);
      } else if (_phase == _Phase.playing || _phase == _Phase.paused) {
        _pauseToggle();
      }
      return KeyEventResult.handled;
    }
    if (isDown && key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grad = widget.palette.gradient(false);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _exitFullscreen();
      },
      child: Scaffold(
        backgroundColor: grad.last,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [grad.first, grad[1], grad.last],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _Hud(
                    score: _score,
                    highScore: _highScore,
                    lives: _lives,
                    level: _level,
                    l10n: l10n,
                    onClose: () => Navigator.of(context).maybePop(),
                    onPause: (_phase == _Phase.playing || _phase == _Phase.paused)
                        ? _pauseToggle
                        : null,
                    paused: _phase == _Phase.paused,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          _layoutField(size);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _focus.requestFocus();
                              if (_phase == _Phase.ready ||
                                  _phase == _Phase.lost) {
                                _startGame();
                              } else if (_phase == _Phase.won) {
                                _startGame(nextLevel: true);
                              }
                            },
                            onHorizontalDragUpdate: (d) {
                              if (_phase != _Phase.playing &&
                                  _phase != _Phase.paused &&
                                  _phase != _Phase.ready) {
                                return;
                              }
                              _paddleX = (d.localPosition.dx - _paddleW / 2)
                                  .clamp(0.0, _field.width - _paddleW);
                              if (_phase == _Phase.ready ||
                                  (_phase == _Phase.playing &&
                                      _vel == Offset.zero)) {
                                _ball = Offset(
                                  _paddleX + _paddleW / 2,
                                  _field.height - 56 - _ballR,
                                );
                              }
                              setState(() {});
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: _ArenaPainter(
                                      ball: _ball,
                                      ballR: _ballR,
                                      paddle: Rect.fromLTWH(
                                        _paddleX,
                                        _field.height - 40,
                                        _paddleW,
                                        14,
                                      ),
                                      bricks: _bricks,
                                      scheme: scheme,
                                      accent: widget.palette.accent,
                                    ),
                                  ),
                                  if (_phase != _Phase.playing)
                                    _OverlayCard(
                                      phase: _phase,
                                      score: _score,
                                      highScore: _highScore,
                                      newRecord: _newRecord,
                                      level: _level,
                                      l10n: l10n,
                                      onPrimary: () {
                                        if (_phase == _Phase.won) {
                                          _startGame(nextLevel: true);
                                        } else if (_phase == _Phase.paused) {
                                          _pauseToggle();
                                        } else {
                                          _startGame();
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.score,
    required this.highScore,
    required this.lives,
    required this.level,
    required this.l10n,
    required this.onClose,
    required this.onPause,
    required this.paused,
  });

  final int score;
  final int highScore;
  final int lives;
  final int level;
  final L10n l10n;
  final VoidCallback onClose;
  final VoidCallback? onPause;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.arkanoidClose,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('${l10n.arkanoidScore}: $score', style: style),
                Text('${l10n.arkanoidRecord}: $highScore', style: style),
                Text('${l10n.arkanoidLevel}: $level', style: style),
                Text(
                  '${l10n.arkanoidLives}: ${'♥' * lives.clamp(0, 5)}',
                  style: style,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: paused ? l10n.arkanoidResume : l10n.arkanoidPause,
            onPressed: onPause,
            icon: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white.withValues(alpha: onPause == null ? 0.35 : 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.phase,
    required this.score,
    required this.highScore,
    required this.newRecord,
    required this.level,
    required this.l10n,
    required this.onPrimary,
  });

  final _Phase phase;
  final int score;
  final int highScore;
  final bool newRecord;
  final int level;
  final L10n l10n;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final (title, body, btn) = switch (phase) {
      _Phase.ready => (
          l10n.arkanoidTitle,
          l10n.arkanoidReadyHint,
          l10n.arkanoidPlay,
        ),
      _Phase.paused => (
          l10n.arkanoidPaused,
          l10n.arkanoidPausedHint,
          l10n.arkanoidResume,
        ),
      _Phase.won => (
          l10n.arkanoidLevelClear(level),
          l10n.arkanoidScoreLine(score, highScore),
          l10n.arkanoidNextLevel,
        ),
      _Phase.lost => (
          l10n.arkanoidGameOver,
          newRecord
              ? l10n.arkanoidNewRecord(score)
              : l10n.arkanoidScoreLine(score, highScore),
          l10n.arkanoidPlayAgain,
        ),
      _Phase.playing => ('', '', ''),
    };

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onPrimary,
                    icon: Icon(
                      phase == _Phase.paused
                          ? Icons.play_arrow_rounded
                          : Icons.sports_esports_rounded,
                    ),
                    label: Text(btn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter({
    required this.ball,
    required this.ballR,
    required this.paddle,
    required this.bricks,
    required this.scheme,
    required this.accent,
  });

  final Offset ball;
  final double ballR;
  final Rect paddle;
  final List<_Brick> bricks;
  final ColorScheme scheme;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.surface.withValues(alpha: 0.22),
          scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ],
      ).createShader(Offset.zero & size);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.2),
    );

    for (final b in bricks) {
      if (!b.alive) continue;
      final br = RRect.fromRectAndRadius(b.rect, const Radius.circular(6));
      canvas.drawRRect(
        br,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(b.color, Colors.white, 0.28)!,
              b.color,
            ],
          ).createShader(b.rect),
      );
      canvas.drawRRect(
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }

    final paddleR = RRect.fromRectAndRadius(paddle, const Radius.circular(8));
    canvas.drawRRect(
      paddleR,
      Paint()
        ..shader = LinearGradient(
          colors: [accent, Color.lerp(accent, Colors.white, 0.35)!],
        ).createShader(paddle),
    );
    canvas.drawRRect(
      paddleR,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.2,
    );

    final ballPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, scheme.primary],
      ).createShader(Rect.fromCircle(center: ball, radius: ballR));
    canvas.drawCircle(ball, ballR, ballPaint);
    canvas.drawCircle(
      ball,
      ballR,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}
