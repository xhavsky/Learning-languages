import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slot garderoby — jedno ubranko na slot.
enum MascotSlot { head, neck, face, body, special }

/// Ubranko / akcesorium — kolory i slot; odblokowywane losowo za poziom.
class MascotItem {
  const MascotItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.slot,
    required this.color,
    this.legacyUnlockLevel,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;
  final MascotSlot slot;
  final Color color;

  /// Stary system (odblokowanie po poziomie) — tylko migracja zapisów.
  final int? legacyUnlockLevel;
}

/// Sklepik kotka — więcej ciuszków w różnych kolorach.
const mascotWardrobe = <MascotItem>[
  MascotItem(
    id: 'bow_pink',
    name: 'Kokardka różowa',
    emoji: '🎀',
    blurb: 'Różowa kokardka — stylowa od razu!',
    slot: MascotSlot.head,
    color: Color(0xFFFF6BA8),
    legacyUnlockLevel: 2,
  ),
  MascotItem(
    id: 'bow_red',
    name: 'Kokardka czerwona',
    emoji: '🎀',
    blurb: 'Czerwona kokardka na wielkie dni.',
    slot: MascotSlot.head,
    color: Color(0xFFE53935),
  ),
  MascotItem(
    id: 'scarf_gray',
    name: 'Szalik szary',
    emoji: '🧣',
    blurb: 'Szary szalik — ciepły i spokojny.',
    slot: MascotSlot.neck,
    color: Color(0xFF90A4AE),
    legacyUnlockLevel: 3,
  ),
  MascotItem(
    id: 'scarf_green',
    name: 'Szalik zielony',
    emoji: '🧣',
    blurb: 'Zielony szalik jak łąka na wiosnę.',
    slot: MascotSlot.neck,
    color: Color(0xFF43A047),
  ),
  MascotItem(
    id: 'scarf_pink',
    name: 'Szalik różowy',
    emoji: '🧣',
    blurb: 'Różowy szalik — cały zestaw z kokardką!',
    slot: MascotSlot.neck,
    color: Color(0xFFF48FB1),
  ),
  MascotItem(
    id: 'hat_black',
    name: 'Czapeczka czarna',
    emoji: '🎩',
    blurb: 'Elegancka czapka jak u prawdziwej pani kotki.',
    slot: MascotSlot.head,
    color: Color(0xFF37474F),
    legacyUnlockLevel: 4,
  ),
  MascotItem(
    id: 'hat_blue',
    name: 'Czapeczka niebieska',
    emoji: '🧢',
    blurb: 'Niebieska czapeczka na naukę na zewnątrz.',
    slot: MascotSlot.head,
    color: Color(0xFF1E88E5),
  ),
  MascotItem(
    id: 'glasses',
    name: 'Okulary mądre',
    emoji: '🤓',
    blurb: 'Mądre okulary do czytania słówek.',
    slot: MascotSlot.face,
    color: Color(0xFF5D4037),
    legacyUnlockLevel: 5,
  ),
  MascotItem(
    id: 'sunglasses',
    name: 'Okulary przeciwsłoneczne',
    emoji: '😎',
    blurb: 'Cool Kicia — nawet przy trudnych słówkach.',
    slot: MascotSlot.face,
    color: Color(0xFF212121),
  ),
  MascotItem(
    id: 'collar_gold',
    name: 'Obroża z dzwonkiem',
    emoji: '🔔',
    blurb: 'Dzwoneczek — słychać, że uczy się!',
    slot: MascotSlot.neck,
    color: Color(0xFFFFB300),
    legacyUnlockLevel: 6,
  ),
  MascotItem(
    id: 'collar_purple',
    name: 'Obroża fioletowa',
    emoji: '💜',
    blurb: 'Fioletowa obroża z serduszkiem.',
    slot: MascotSlot.neck,
    color: Color(0xFF8E24AA),
  ),
  MascotItem(
    id: 'sweater_yellow',
    name: 'Sweterek żółty',
    emoji: '💛',
    blurb: 'Cieplutki żółty sweterek.',
    slot: MascotSlot.body,
    color: Color(0xFFFFCA28),
  ),
  MascotItem(
    id: 'sweater_blue',
    name: 'Sweterek błękitny',
    emoji: '💙',
    blurb: 'Błękitny sweterek jak niebo.',
    slot: MascotSlot.body,
    color: Color(0xFF4FC3F7),
  ),
  MascotItem(
    id: 'cape_red',
    name: 'Pelerynka czerwona',
    emoji: '🦸',
    blurb: 'Superbohaterka języków!',
    slot: MascotSlot.body,
    color: Color(0xFFE53935),
    legacyUnlockLevel: 8,
  ),
  MascotItem(
    id: 'cape_teal',
    name: 'Pelerynka turkusowa',
    emoji: '🦸‍♀️',
    blurb: 'Turkusowa pelerynka — szybka jak słówko!',
    slot: MascotSlot.body,
    color: Color(0xFF00897B),
  ),
  MascotItem(
    id: 'flower_yellow',
    name: 'Kwiatek za uchem',
    emoji: '🌼',
    blurb: 'Żółty kwiatek — pachnie nauką.',
    slot: MascotSlot.head,
    color: Color(0xFFFFEE58),
  ),
  MascotItem(
    id: 'crown',
    name: 'Korona',
    emoji: '👑',
    blurb: 'Królowa passy i XP.',
    slot: MascotSlot.head,
    color: Color(0xFFFFD54F),
    legacyUnlockLevel: 10,
  ),
  MascotItem(
    id: 'backpack',
    name: 'Plecaczek',
    emoji: '🎒',
    blurb: 'Na wycieczki ze słówkami.',
    slot: MascotSlot.special,
    color: Color(0xFFEF6C00),
    legacyUnlockLevel: 12,
  ),
  MascotItem(
    id: 'star',
    name: 'Gwiazdka',
    emoji: '⭐',
    blurb: 'Świecisz jak gwiazda Treningu.',
    slot: MascotSlot.special,
    color: Color(0xFFFFCA28),
    legacyUnlockLevel: 15,
  ),
  MascotItem(
    id: 'wings',
    name: 'Skrzydełka',
    emoji: '🪽',
    blurb: 'Leci na level MAX!',
    slot: MascotSlot.special,
    color: Color(0xFFB3E5FC),
    legacyUnlockLevel: 20,
  ),
  MascotItem(
    id: 'headphones',
    name: 'Słuchawki',
    emoji: '🎧',
    blurb: 'Słuchawki do powtórek audio.',
    slot: MascotSlot.head,
    color: Color(0xFF7E57C2),
  ),
  MascotItem(
    id: 'bandana_orange',
    name: 'Chustka pomarańczowa',
    emoji: '🧡',
    blurb: 'Pomarańczowa chustka — gotowa do quizu!',
    slot: MascotSlot.neck,
    color: Color(0xFFFF7043),
  ),
];

/// Ile słówek dziennie trzeba „nakarmić” Kicię.
const mascotDailyFeedGoal = 5;

MascotItem? mascotItemById(String id) {
  for (final item in mascotWardrobe) {
    if (item.id == id) return item;
  }
  return null;
}

/// @Deprecated — zostawione pod stare testy; nagrody są teraz losowe.
MascotItem? mascotItemForLevel(int level) {
  for (final item in mascotWardrobe) {
    if (item.legacyUnlockLevel == level) return item;
  }
  return null;
}

List<MascotItem> unlockedMascotItems(Iterable<String> unlockedIds) {
  final set = unlockedIds.toSet();
  return [for (final item in mascotWardrobe) if (set.contains(item.id)) item];
}

List<MascotItem> lockedMascotItems(Iterable<String> unlockedIds) {
  final set = unlockedIds.toSet();
  return [for (final item in mascotWardrobe) if (!set.contains(item.id)) item];
}

/// Losuje jedno nowe ubranko spośród jeszcze zablokowanych.
MascotItem? rollMascotReward(
  Iterable<String> unlockedIds, {
  math.Random? random,
}) {
  final locked = lockedMascotItems(unlockedIds);
  if (locked.isEmpty) return null;
  final rng = random ?? math.Random();
  return locked[rng.nextInt(locked.length)];
}

/// Migracja ze starego „od poziomu X” → lista id.
List<String> migrateUnlockedFromLevel(int playerLevel) {
  return [
    for (final item in mascotWardrobe)
      if (item.legacyUnlockLevel != null &&
          playerLevel >= item.legacyUnlockLevel!)
        item.id,
  ];
}

String slotLabel(MascotSlot slot) => switch (slot) {
      MascotSlot.head => 'Głowa',
      MascotSlot.neck => 'Szyja',
      MascotSlot.face => 'Buzia',
      MascotSlot.body => 'Ciałko',
      MascotSlot.special => 'Specjalne',
    };

/// Kreskówkowa Kicia z namalowanymi ubrankami (naprawdę „ma je na sobie”).
class DressedKicia extends StatelessWidget {
  const DressedKicia({
    super.key,
    required this.equipped,
    this.size = 220,
  });

  /// slot.name → itemId
  final Map<String, String> equipped;
  final double size;

  List<MascotItem> get _worn {
    final out = <MascotItem>[];
    for (final id in equipped.values) {
      final item = mascotItemById(id);
      if (item != null) out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final worn = _worn;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/kicia_base.png',
              fit: BoxFit.cover,
              width: size,
              height: size,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _OutfitPainter(worn),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutfitPainter extends CustomPainter {
  _OutfitPainter(this.items);

  final List<MascotItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (final item in items) {
      switch (item.slot) {
        case MascotSlot.body:
          _paintBody(canvas, w, h, item);
        case MascotSlot.neck:
          _paintNeck(canvas, w, h, item);
        case MascotSlot.face:
          _paintFace(canvas, w, h, item);
        case MascotSlot.head:
          _paintHead(canvas, w, h, item);
        case MascotSlot.special:
          _paintSpecial(canvas, w, h, item);
      }
    }
  }

  void _paintBody(Canvas canvas, double w, double h, MascotItem item) {
    final paint = Paint()..color = item.color.withValues(alpha: 0.92);
    if (item.id.startsWith('cape')) {
      final path = Path()
        ..moveTo(w * 0.22, h * 0.42)
        ..quadraticBezierTo(w * 0.05, h * 0.62, w * 0.18, h * 0.88)
        ..lineTo(w * 0.82, h * 0.88)
        ..quadraticBezierTo(w * 0.95, h * 0.62, w * 0.78, h * 0.42)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      // sweterek
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.28, h * 0.48, w * 0.72, h * 0.82),
        const Radius.circular(28),
      );
      canvas.drawRRect(r, paint);
      canvas.drawRRect(
        r,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _paintNeck(Canvas canvas, double w, double h, MascotItem item) {
    final paint = Paint()
      ..color = item.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    if (item.id.startsWith('scarf') || item.id.startsWith('bandana')) {
      final path = Path()
        ..moveTo(w * 0.28, h * 0.48)
        ..quadraticBezierTo(w * 0.5, h * 0.58, w * 0.72, h * 0.48);
      canvas.drawPath(path, paint);
      // końcówki szalika
      final tip = Paint()..color = item.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.58, h * 0.62),
            width: w * 0.12,
            height: h * 0.22,
          ),
          const Radius.circular(8),
        ),
        tip,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.68, h * 0.60),
            width: w * 0.10,
            height: h * 0.18,
          ),
          const Radius.circular(8),
        ),
        tip,
      );
    } else {
      // obroża
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.48),
          width: w * 0.38,
          height: h * 0.14,
        ),
        0.15,
        2.85,
        false,
        paint..strokeWidth = w * 0.045,
      );
      final bell = Paint()..color = const Color(0xFFFFD54F);
      canvas.drawCircle(Offset(w * 0.5, h * 0.56), w * 0.045, bell);
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.57),
        w * 0.012,
        Paint()..color = Colors.black54,
      );
    }
  }

  void _paintFace(Canvas canvas, double w, double h, MascotItem item) {
    final frame = Paint()
      ..color = item.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028;
    final left = Offset(w * 0.38, h * 0.36);
    final right = Offset(w * 0.62, h * 0.36);
    final r = w * 0.08;
    canvas.drawCircle(left, r, frame);
    canvas.drawCircle(right, r, frame);
    canvas.drawLine(
      Offset(left.dx + r, left.dy),
      Offset(right.dx - r, right.dy),
      frame,
    );
    if (item.id == 'sunglasses') {
      final lens = Paint()..color = item.color.withValues(alpha: 0.55);
      canvas.drawCircle(left, r * 0.85, lens);
      canvas.drawCircle(right, r * 0.85, lens);
    }
  }

  void _paintHead(Canvas canvas, double w, double h, MascotItem item) {
    final paint = Paint()..color = item.color;
    if (item.id.startsWith('bow')) {
      final cx = w * 0.62;
      final cy = h * 0.16;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - w * 0.05, cy), width: w * 0.1, height: h * 0.08),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + w * 0.05, cy), width: w * 0.1, height: h * 0.08),
        paint,
      );
      canvas.drawCircle(Offset(cx, cy), w * 0.028, paint);
    } else if (item.id.startsWith('hat')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.32, h * 0.02, w * 0.68, h * 0.14),
          const Radius.circular(6),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.22, h * 0.12, w * 0.78, h * 0.17),
          const Radius.circular(8),
        ),
        paint,
      );
    } else if (item.id == 'crown') {
      final path = Path()
        ..moveTo(w * 0.30, h * 0.16)
        ..lineTo(w * 0.36, h * 0.04)
        ..lineTo(w * 0.44, h * 0.12)
        ..lineTo(w * 0.50, h * 0.02)
        ..lineTo(w * 0.56, h * 0.12)
        ..lineTo(w * 0.64, h * 0.04)
        ..lineTo(w * 0.70, h * 0.16)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawCircle(Offset(w * 0.50, h * 0.06), w * 0.02, Paint()..color = Colors.redAccent);
    } else if (item.id == 'flower_yellow') {
      final c = Offset(w * 0.72, h * 0.22);
      for (var i = 0; i < 5; i++) {
        final a = i * 1.256;
        canvas.drawCircle(
          Offset(c.dx + math.cos(a) * w * 0.035, c.dy + math.sin(a) * w * 0.035),
          w * 0.028,
          paint,
        );
      }
      canvas.drawCircle(c, w * 0.022, Paint()..color = const Color(0xFFFF8F00));
    } else if (item.id == 'headphones') {
      final band = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromLTRB(w * 0.22, h * 0.08, w * 0.78, h * 0.42),
        3.5,
        2.4,
        false,
        band,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w * 0.24, h * 0.34), width: w * 0.08, height: h * 0.12),
          const Radius.circular(10),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w * 0.76, h * 0.34), width: w * 0.08, height: h * 0.12),
          const Radius.circular(10),
        ),
        paint,
      );
    }
  }

  void _paintSpecial(Canvas canvas, double w, double h, MascotItem item) {
    final paint = Paint()..color = item.color;
    if (item.id == 'backpack') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.72, h * 0.48, w * 0.92, h * 0.78),
          const Radius.circular(12),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.74, h * 0.50, w * 0.90, h * 0.58),
          const Radius.circular(6),
        ),
        Paint()..color = Colors.white54,
      );
    } else if (item.id == 'star') {
      _drawStar(canvas, Offset(w * 0.84, h * 0.18), w * 0.08, paint);
    } else if (item.id == 'wings') {
      final wing = Paint()..color = item.color.withValues(alpha: 0.85);
      final left = Path()
        ..moveTo(w * 0.28, h * 0.50)
        ..quadraticBezierTo(w * 0.02, h * 0.40, w * 0.08, h * 0.68)
        ..quadraticBezierTo(w * 0.18, h * 0.62, w * 0.28, h * 0.55)
        ..close();
      final right = Path()
        ..moveTo(w * 0.72, h * 0.50)
        ..quadraticBezierTo(w * 0.98, h * 0.40, w * 0.92, h * 0.68)
        ..quadraticBezierTo(w * 0.82, h * 0.62, w * 0.72, h * 0.55)
        ..close();
      canvas.drawPath(left, wing);
      canvas.drawPath(right, wing);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 4 * math.pi / 5;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OutfitPainter oldDelegate) {
    if (oldDelegate.items.length != items.length) return true;
    for (var i = 0; i < items.length; i++) {
      if (oldDelegate.items[i].id != items[i].id) return true;
    }
    return false;
  }
}

/// Widget kotka: zdjęcie + kreskówka w stroju + status karmienia.
class MascotCard extends StatelessWidget {
  const MascotCard({
    super.key,
    required this.playerLevel,
    required this.wordsToday,
    required this.fedToday,
    required this.unlockedIds,
    required this.equipped,
    this.compact = false,
    this.onTapWardrobe,
    this.onEquip,
  });

  final int playerLevel;
  final int wordsToday;
  final bool fedToday;
  final List<String> unlockedIds;
  final Map<String, String> equipped;
  final bool compact;
  final VoidCallback? onTapWardrobe;
  final void Function(MascotItem item)? onEquip;

  @override
  Widget build(BuildContext context) {
    final items = unlockedMascotItems(unlockedIds);
    final need =
        (mascotDailyFeedGoal - wordsToday).clamp(0, mascotDailyFeedGoal);
    final hungerLabel = fedToday
        ? 'Syta i szczęśliwa! (+nauka dziś ✓)'
        : need == 0
            ? 'Już najedzona — możesz dalej ćwiczyć.'
            : 'Głodna… nakarm nauką: jeszcze $need słówk${need == 1 ? 'o' : 'a'} dziś';

    final portraitSize = compact ? 120.0 : 160.0;

    return Softish(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Zdjęcie',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/kitten_book.png',
                        fit: BoxFit.cover,
                        height: portraitSize,
                        width: portraitSize,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Kicia w stroju',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    DressedKicia(equipped: equipped, size: portraitSize),
                  ],
                ),
              ),
            ],
          ),
          if (!fedToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Miaaa… jem słówka!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Kicia — maskotka Treningu',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hungerLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (wordsToday / mascotDailyFeedGoal).clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Karma dziś: $wordsToday / $mascotDailyFeedGoal słówek',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Garderoba — stuknij, żeby ubrać (${items.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final it in items)
                  FilterChip(
                    selected: equipped[it.slot.name] == it.id,
                    avatar: CircleAvatar(
                      backgroundColor: it.color,
                      child: Text(it.emoji, style: const TextStyle(fontSize: 12)),
                    ),
                    label: Text(it.name),
                    visualDensity: VisualDensity.compact,
                    onSelected: onEquip == null
                        ? null
                        : (_) => onEquip!(it),
                  ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Awansuj na poziom 2 — Kicia dostanie losowe ubranko!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (onTapWardrobe != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onTapWardrobe,
              child: const Text('Pełna garderoba'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lekki panel bez zależności od SoftPanel z ui_fx (unikamy cyklu importów).
class Softish extends StatelessWidget {
  const Softish({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}
