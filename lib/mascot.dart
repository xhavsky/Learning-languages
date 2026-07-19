import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gatunek maskotki.
enum MascotSpecies { cat, dog }

/// Domyślny kolor futerka (kremowy — jak Kicia na obrazku).
const defaultMascotColorArgb = 0xFFFFCC80;

/// Paleta kolorów do wyboru.
const mascotColorPresets = <Color>[
  Color(0xFFFFCC80), // kremowy
  Color(0xFFFF8A65), // rudy
  Color(0xFFBDBDBD), // szary
  Color(0xFF5D4037), // brązowy
  Color(0xFF212121), // czarny
  Color(0xFFFFF8E1), // biały
  Color(0xFFF48FB1), // różowy
  Color(0xFF90CAF9), // błękitny
];

String mascotSpeciesLabel(MascotSpecies s) =>
    s == MascotSpecies.cat ? 'Kot' : 'Pies';

String mascotName(MascotSpecies s) =>
    s == MascotSpecies.cat ? 'Kicia' : 'Piesek';

/// Slot garderoby — jedno ubranko na slot.
enum MascotSlot { head, neck, face, body, special }

/// Slot pokoiku Kici (miska, posłanie…).
enum HomeSlot { bowl, bed, toy, decor }

/// Ubranko / akcesorium — kolory i slot; losowo za poziom albo ze sklepu.
class MascotItem {
  const MascotItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.slot,
    required this.color,
    this.legacyUnlockLevel,
    this.shopPrice,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;
  final MascotSlot slot;
  final Color color;

  /// Stary system (odblokowanie po poziomie) — tylko migracja zapisów.
  final int? legacyUnlockLevel;

  /// Cena w złotych łapkach (tylko sklep; nie wylosujesz za poziom).
  final int? shopPrice;

  bool get isShopExclusive => shopPrice != null;
}

/// Miska / posłanie / zabawka — kupujesz w sklepie za złote łapki.
class HomeItem {
  const HomeItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.slot,
    required this.price,
    required this.color,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;
  final HomeSlot slot;
  final int price;
  final Color color;
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
  // —— Ekskluzywne ubranka ze sklepu (złote łapki) ——
  MascotItem(
    id: 'dress_sparkle',
    name: 'Sukienka brokatowa',
    emoji: '✨',
    blurb: 'Brokatowa sukienka tylko ze sklepu!',
    slot: MascotSlot.body,
    color: Color(0xFFE040FB),
    shopPrice: 25,
  ),
  MascotItem(
    id: 'bow_gold',
    name: 'Kokardka złota',
    emoji: '💛',
    blurb: 'Złota kokardka — luksusowa Kicia.',
    slot: MascotSlot.head,
    color: Color(0xFFFFD700),
    shopPrice: 18,
  ),
  MascotItem(
    id: 'boots_pink',
    name: 'Buciki różowe',
    emoji: '👢',
    blurb: 'Różowe buciki na spacer ze słówkami.',
    slot: MascotSlot.special,
    color: Color(0xFFFF80AB),
    shopPrice: 22,
  ),
  MascotItem(
    id: 'tiara_crystal',
    name: 'Diadem kryształowy',
    emoji: '💎',
    blurb: 'Diadem jak z bajki — tylko w sklepie.',
    slot: MascotSlot.head,
    color: Color(0xFF81D4FA),
    shopPrice: 35,
  ),
  MascotItem(
    id: 'scarf_rainbow',
    name: 'Szalik tęczowy',
    emoji: '🌈',
    blurb: 'Tęczowy szalik — wszystkie kolory naraz!',
    slot: MascotSlot.neck,
    color: Color(0xFFAB47BC),
    shopPrice: 20,
  ),
];

/// Sklepik: miski, posłanie i gadżety do pokoiku.
const mascotHomeShop = <HomeItem>[
  HomeItem(
    id: 'bowl_pink',
    name: 'Miska różowa',
    emoji: '🥣',
    blurb: 'Prawdziwa różowa miseczka na smaczki-słówka.',
    slot: HomeSlot.bowl,
    price: 8,
    color: Color(0xFFFF69B4),
  ),
  HomeItem(
    id: 'bowl_gold',
    name: 'Miska złota',
    emoji: '🥇',
    blurb: 'Złota miska dla prawdziwej królowej.',
    slot: HomeSlot.bowl,
    price: 15,
    color: Color(0xFFFFD700),
  ),
  HomeItem(
    id: 'bed_soft',
    name: 'Posłanie miękkie',
    emoji: '🛏️',
    blurb: 'Mięciutkie posłanie — drzemka po nauce.',
    slot: HomeSlot.bed,
    price: 12,
    color: Color(0xFF64B5F6),
  ),
  HomeItem(
    id: 'bed_castle',
    name: 'Posłanie-zamek',
    emoji: '🏰',
    blurb: 'Posłanie jak mały zamek!',
    slot: HomeSlot.bed,
    price: 28,
    color: Color(0xFFBA68C8),
  ),
  HomeItem(
    id: 'toy_mouse',
    name: 'Myszka na sznurku',
    emoji: '🐭',
    blurb: 'Ulubiona zabawka do gonienia.',
    slot: HomeSlot.toy,
    price: 10,
    color: Color(0xFFFF8A65),
  ),
  HomeItem(
    id: 'toy_ball',
    name: 'Piłeczka dzwoniąca',
    emoji: '🔔',
    blurb: 'Piłeczka — bawi się między quizami.',
    slot: HomeSlot.toy,
    price: 9,
    color: Color(0xFF26A69A),
  ),
  HomeItem(
    id: 'plant_catnip',
    name: 'Doniczka kocimiętki',
    emoji: '🌿',
    blurb: 'Zielony kącik w pokoiku.',
    slot: HomeSlot.decor,
    price: 11,
    color: Color(0xFF66BB6A),
  ),
  HomeItem(
    id: 'lamp_moon',
    name: 'Lampka księżyc',
    emoji: '🌙',
    blurb: 'Miękkie światło na wieczorne słówka.',
    slot: HomeSlot.decor,
    price: 16,
    color: Color(0xFFFFEE58),
  ),
];

/// Ile słówek dziennie trzeba „nakarmić” Kicię.
const mascotDailyFeedGoal = 5;

/// Ile złotych łapek za poprawną odpowiedź.
const pawsPerCorrect = 1;

/// Bonus łapek gdy Kicia właśnie osiągnie cel karmienia.
const pawsFeedBonus = 3;

/// Bonus łapek za awans poziomu.
const pawsPerLevelUp = 5;

/// Bonus łapek za codzienną rozmowę AI.
const pawsDailyChat = 2;

MascotItem? mascotItemById(String id) {
  for (final item in mascotWardrobe) {
    if (item.id == id) return item;
  }
  return null;
}

HomeItem? homeItemById(String id) {
  for (final item in mascotHomeShop) {
    if (item.id == id) return item;
  }
  return null;
}

/// Ubranka dostępne tylko za złote łapki.
List<MascotItem> shopExclusiveOutfits() =>
    [for (final item in mascotWardrobe) if (item.isShopExclusive) item];

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
  return [
    for (final item in mascotWardrobe)
      if (!set.contains(item.id) && !item.isShopExclusive) item,
  ];
}

/// Losuje jedno nowe ubranko spośród jeszcze zablokowanych (bez sklepowych).
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

String homeSlotLabel(HomeSlot slot) => switch (slot) {
      HomeSlot.bowl => 'Miska',
      HomeSlot.bed => 'Posłanie',
      HomeSlot.toy => 'Zabawka',
      HomeSlot.decor => 'Dekoracja',
    };

/// Kreskówkowa maskotka z namalowanymi ubrankami i pokoikiem.
class DressedKicia extends StatelessWidget {
  const DressedKicia({
    super.key,
    required this.equipped,
    this.placedHome = const {},
    this.species = MascotSpecies.cat,
    this.furColor = const Color(defaultMascotColorArgb),
    this.size = 220,
  });

  /// slot.name → itemId
  final Map<String, String> equipped;

  /// HomeSlot.name → homeItemId
  final Map<String, String> placedHome;
  final MascotSpecies species;
  final Color furColor;
  final double size;

  List<MascotItem> get _worn {
    final out = <MascotItem>[];
    for (final id in equipped.values) {
      final item = mascotItemById(id);
      if (item != null) out.add(item);
    }
    return out;
  }

  List<HomeItem> get _home {
    final out = <HomeItem>[];
    for (final id in placedHome.values) {
      final item = homeItemById(id);
      if (item != null) out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final worn = _worn;
    final home = _home;
    final tinted = furColor.toARGB32() != defaultMascotColorArgb;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (species == MascotSpecies.cat)
            tinted
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      furColor.withValues(alpha: 0.55),
                      BlendMode.modulate,
                    ),
                    child: Image.asset(
                      'assets/images/kicia_base.png',
                      fit: BoxFit.contain,
                      width: size,
                      height: size,
                      filterQuality: FilterQuality.medium,
                    ),
                  )
                : Image.asset(
                    'assets/images/kicia_base.png',
                    fit: BoxFit.contain,
                    width: size,
                    height: size,
                    filterQuality: FilterQuality.medium,
                  )
          else
            CustomPaint(
              size: Size(size, size),
              painter: _DogPainter(furColor),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: _OutfitPainter(worn),
            ),
          ),
          for (final h in home) _homeArt(h),
        ],
      ),
    );
  }

  Widget _homeArt(HomeItem item) {
    final (Alignment align, double dx, double dy) = switch (item.slot) {
      HomeSlot.bowl => (Alignment.bottomLeft, 2.0, -2.0),
      HomeSlot.bed => (Alignment.bottomRight, -2.0, -2.0),
      HomeSlot.toy => (Alignment.centerLeft, -4.0, 22.0),
      HomeSlot.decor => (Alignment.topRight, -2.0, 10.0),
    };
    final artSize = size * 0.28;
    return Align(
      alignment: align,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: HomeItemArt(item: item, size: artSize),
      ),
    );
  }
}

/// Miniaturka rzeczy ze sklepu / pokoiku — prawdziwy rysunek, nie kolorowe tło.
class HomeItemArt extends StatelessWidget {
  const HomeItemArt({super.key, required this.item, this.size = 48});

  final HomeItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HomeItemPainter(item),
      ),
    );
  }
}

/// Miniaturka ubranka do sklepu / listy.
class OutfitThumb extends StatelessWidget {
  const OutfitThumb({super.key, required this.item, this.size = 48});

  final MascotItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            item.color.withValues(alpha: 0.95),
            item.color.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(item.emoji, style: TextStyle(fontSize: size * 0.42)),
      ),
    );
  }
}

class _HomeItemPainter extends CustomPainter {
  _HomeItemPainter(this.item);

  final HomeItem item;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (item.id) {
      case 'bowl_pink':
      case 'bowl_gold':
        _paintBowl(canvas, w, h, item.color);
      case 'bed_soft':
        _paintBedSoft(canvas, w, h, item.color);
      case 'bed_castle':
        _paintBedCastle(canvas, w, h, item.color);
      case 'toy_mouse':
        _paintMouse(canvas, w, h, item.color);
      case 'toy_ball':
        _paintBall(canvas, w, h, item.color);
      case 'plant_catnip':
        _paintPlant(canvas, w, h, item.color);
      case 'lamp_moon':
        _paintMoon(canvas, w, h, item.color);
      default:
        final p = Paint()..color = item.color;
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.35, p);
    }
  }

  void _paintBowl(Canvas canvas, double w, double h, Color color) {
    // Cień
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.78),
        width: w * 0.7,
        height: h * 0.12,
      ),
      Paint()..color = Colors.black26,
    );
    // Korpus miski — sam kolor (różowy / złoty), bez kolorowego tła
    final bowl = Path()
      ..moveTo(w * 0.18, h * 0.38)
      ..quadraticBezierTo(w * 0.12, h * 0.72, w * 0.28, h * 0.78)
      ..lineTo(w * 0.72, h * 0.78)
      ..quadraticBezierTo(w * 0.88, h * 0.72, w * 0.82, h * 0.38)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
          Color.lerp(color, Colors.black, 0.15)!,
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.3, w, h * 0.55));
    canvas.drawPath(bowl, fill);
    canvas.drawPath(
      bowl,
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.25)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // Wewnętrzna elipsa (pokarm / połysk)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.42),
        width: w * 0.58,
        height: h * 0.18,
      ),
      Paint()..color = Color.lerp(color, Colors.white, 0.45)!,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.44),
        width: w * 0.42,
        height: h * 0.10,
      ),
      Paint()..color = const Color(0xFFFFE0B2).withValues(alpha: 0.85),
    );
    // Błysk
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.38, h * 0.52),
        width: w * 0.08,
        height: h * 0.16,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  void _paintBedSoft(Canvas canvas, double w, double h, Color color) {
    final base = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.12, h * 0.45, w * 0.88, h * 0.82),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.35)!],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawOval(
      Rect.fromLTRB(w * 0.22, h * 0.38, w * 0.78, h * 0.62),
      Paint()..color = Color.lerp(color, Colors.white, 0.4)!,
    );
    canvas.drawRRect(
      base,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintBedCastle(Canvas canvas, double w, double h, Color color) {
    final wall = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.18, h * 0.42, w * 0.82, h * 0.82),
        const Radius.circular(6),
      ),
      wall,
    );
    for (final x in [0.22, 0.42, 0.62]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * x, h * 0.22, w * (x + 0.16), h * 0.45),
          const Radius.circular(3),
        ),
        wall,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.38, h * 0.55, w * 0.62, h * 0.82),
        const Radius.circular(4),
      ),
      Paint()..color = Color.lerp(color, Colors.black, 0.25)!,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.18),
      w * 0.06,
      Paint()..color = const Color(0xFFFFD54F),
    );
  }

  void _paintMouse(Canvas canvas, double w, double h, Color color) {
    final body = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.48, h * 0.55),
        width: w * 0.55,
        height: h * 0.38,
      ),
      body,
    );
    canvas.drawCircle(Offset(w * 0.72, h * 0.42), w * 0.14, body);
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.28),
      w * 0.08,
      Paint()..color = Color.lerp(color, Colors.pink, 0.3)!,
    );
    canvas.drawCircle(
      Offset(w * 0.80, h * 0.30),
      w * 0.08,
      Paint()..color = Color.lerp(color, Colors.pink, 0.3)!,
    );
    canvas.drawCircle(
      Offset(w * 0.76, h * 0.40),
      w * 0.025,
      Paint()..color = Colors.black87,
    );
    final string = Paint()
      ..color = Colors.brown.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromLTRB(w * 0.05, h * 0.35, w * 0.35, h * 0.7),
      0.2,
      2.2,
      false,
      string,
    );
  }

  void _paintBall(Canvas canvas, double w, double h, Color color) {
    final c = Offset(w * 0.5, h * 0.5);
    canvas.drawCircle(
      c,
      w * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.4)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: w * 0.32)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: w * 0.32),
      -0.4,
      2.2,
      false,
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.06,
      Paint()..color = const Color(0xFFFFD54F),
    );
  }

  void _paintPlant(Canvas canvas, double w, double h, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.32, h * 0.55, w * 0.68, h * 0.88),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final leaf = Paint()..color = color;
    for (final (dx, dy, rx, ry) in [
      (0.5, 0.42, 0.12, 0.28),
      (0.36, 0.38, 0.10, 0.24),
      (0.64, 0.38, 0.10, 0.24),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * dx, h * dy),
          width: w * rx * 2,
          height: h * ry,
        ),
        leaf,
      );
    }
  }

  void _paintMoon(Canvas canvas, double w, double h, Color color) {
    final c = Offset(w * 0.5, h * 0.48);
    canvas.drawCircle(
      c,
      w * 0.28,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(c, w * 0.26, Paint()..color = color);
    canvas.drawCircle(
      Offset(w * 0.60, h * 0.42),
      w * 0.18,
      Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(w * 0.42, h * 0.40),
      w * 0.04,
      Paint()..color = Colors.white70,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeItemPainter oldDelegate) =>
      oldDelegate.item.id != item.id;
}

/// Rysunek pieska (gdy wybrany gatunek = pies).
class _DogPainter extends CustomPainter {
  _DogPainter(this.fur);

  final Color fur;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = fur;
    final dark = Paint()..color = Color.lerp(fur, Colors.black, 0.22)!;
    final light = Paint()..color = Color.lerp(fur, Colors.white, 0.35)!;

    // Uszy
    final leftEar = Path()
      ..moveTo(w * 0.28, h * 0.28)
      ..lineTo(w * 0.18, h * 0.08)
      ..lineTo(w * 0.38, h * 0.22)
      ..close();
    final rightEar = Path()
      ..moveTo(w * 0.72, h * 0.28)
      ..lineTo(w * 0.82, h * 0.08)
      ..lineTo(w * 0.62, h * 0.22)
      ..close();
    canvas.drawPath(leftEar, dark);
    canvas.drawPath(rightEar, dark);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.29, h * 0.26)
        ..lineTo(w * 0.22, h * 0.12)
        ..lineTo(w * 0.36, h * 0.22)
        ..close(),
      Paint()..color = const Color(0xFFFFCDD2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.71, h * 0.26)
        ..lineTo(w * 0.78, h * 0.12)
        ..lineTo(w * 0.64, h * 0.22)
        ..close(),
      Paint()..color = const Color(0xFFFFCDD2),
    );

    // Głowa
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.38),
        width: w * 0.52,
        height: h * 0.42,
      ),
      body,
    );
    // Pyszczek
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.48),
        width: w * 0.28,
        height: h * 0.18,
      ),
      light,
    );
    // Oczy
    canvas.drawCircle(Offset(w * 0.40, h * 0.34), w * 0.045, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(w * 0.60, h * 0.34), w * 0.045, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(w * 0.415, h * 0.325), w * 0.015, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.615, h * 0.325), w * 0.015, Paint()..color = Colors.white);
    // Nosek
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.46),
        width: w * 0.08,
        height: h * 0.05,
      ),
      Paint()..color = Colors.black87,
    );
    // Uśmiech
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.50),
        width: w * 0.16,
        height: h * 0.10,
      ),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // Ciało
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.28, h * 0.55, w * 0.72, h * 0.88),
        const Radius.circular(28),
      ),
      body,
    );
    // Łapki
    canvas.drawOval(
      Rect.fromLTRB(w * 0.30, h * 0.82, w * 0.44, h * 0.94),
      dark,
    );
    canvas.drawOval(
      Rect.fromLTRB(w * 0.56, h * 0.82, w * 0.70, h * 0.94),
      dark,
    );
    // Ogon
    canvas.drawArc(
      Rect.fromLTRB(w * 0.68, h * 0.58, w * 0.95, h * 0.85),
      -0.8,
      1.6,
      false,
      Paint()
        ..color = fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DogPainter oldDelegate) =>
      oldDelegate.fur.toARGB32() != fur.toARGB32();
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
    } else if (item.id == 'tiara_crystal') {
      final path = Path()
        ..moveTo(w * 0.32, h * 0.14)
        ..lineTo(w * 0.38, h * 0.05)
        ..lineTo(w * 0.44, h * 0.12)
        ..lineTo(w * 0.50, h * 0.02)
        ..lineTo(w * 0.56, h * 0.12)
        ..lineTo(w * 0.62, h * 0.05)
        ..lineTo(w * 0.68, h * 0.14)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        Offset(w * 0.50, h * 0.06),
        w * 0.025,
        Paint()..color = Colors.white,
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
    } else if (item.id.startsWith('boots')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.30, h * 0.78, w * 0.44, h * 0.92),
          const Radius.circular(8),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.56, h * 0.78, w * 0.70, h * 0.92),
          const Radius.circular(8),
        ),
        paint,
      );
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

/// Widget maskotki: kreskówka w stroju + pokoik + status karmienia.
class MascotCard extends StatelessWidget {
  const MascotCard({
    super.key,
    required this.playerLevel,
    required this.wordsToday,
    required this.fedToday,
    required this.unlockedIds,
    required this.equipped,
    required this.goldenPaws,
    this.placedHome = const {},
    this.species = MascotSpecies.cat,
    this.furColor = const Color(defaultMascotColorArgb),
    this.compact = false,
    this.onTapWardrobe,
    this.onTapShop,
    this.onEquip,
    this.onSpeciesChanged,
    this.onColorChanged,
  });

  final int playerLevel;
  final int wordsToday;
  final bool fedToday;
  final List<String> unlockedIds;
  final Map<String, String> equipped;
  final Map<String, String> placedHome;
  final MascotSpecies species;
  final Color furColor;
  final int goldenPaws;
  final bool compact;
  final VoidCallback? onTapWardrobe;
  final VoidCallback? onTapShop;
  final void Function(MascotItem item)? onEquip;
  final void Function(MascotSpecies species)? onSpeciesChanged;
  final void Function(Color color)? onColorChanged;

  @override
  Widget build(BuildContext context) {
    final items = unlockedMascotItems(unlockedIds);
    final need =
        (mascotDailyFeedGoal - wordsToday).clamp(0, mascotDailyFeedGoal);
    final name = mascotName(species);
    final hungerLabel = fedToday
        ? 'Syta i szczęśliwa! (+nauka dziś ✓)'
        : need == 0
            ? 'Już najedzona — możesz dalej ćwiczyć.'
            : 'Głodna… nakarm nauką: jeszcze $need słówk${need == 1 ? 'o' : 'a'} dziś';

    final portraitSize = compact ? 140.0 : 200.0;

    return Softish(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$name — maskotka Treningu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Text(
                  '🐾 $goldenPaws',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8D6E00),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (onSpeciesChanged != null) ...[
            SegmentedButton<MascotSpecies>(
              segments: const [
                ButtonSegment(
                  value: MascotSpecies.cat,
                  label: Text('🐱 Kot'),
                ),
                ButtonSegment(
                  value: MascotSpecies.dog,
                  label: Text('🐶 Pies'),
                ),
              ],
              selected: {species},
              onSelectionChanged: (s) => onSpeciesChanged!(s.first),
            ),
            const SizedBox(height: 8),
          ],
          if (onColorChanged != null) ...[
            Text(
              'Kolor futerka',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in mascotColorPresets)
                  GestureDetector(
                    onTap: () => onColorChanged!(c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: furColor.toARGB32() == c.toARGB32()
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                          width: furColor.toARGB32() == c.toARGB32() ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: DressedKicia(
              equipped: equipped,
              placedHome: placedHome,
              species: species,
              furColor: furColor,
              size: portraitSize,
            ),
          ),
          if (!fedToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  species == MascotSpecies.dog
                      ? 'Hau! Jem słówka!'
                      : 'Miaaa… jem słówka!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            hungerLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Zbieraj złote łapki 🐾 za poprawne odpowiedzi i kupuj '
            'miski, posłanie oraz ekskluzywne ubranka w sklepie!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
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
                    avatar: OutfitThumb(item: it, size: 28),
                    label: Text(it.name),
                    visualDensity: VisualDensity.compact,
                    onSelected: onEquip == null ? null : (_) => onEquip!(it),
                  ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Awansuj na poziom 2 albo zajrzyj do sklepu — $name dostanie ubranko!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              if (onTapShop != null)
                FilledButton.tonalIcon(
                  onPressed: onTapShop,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Sklep'),
                ),
              if (onTapWardrobe != null)
                TextButton(
                  onPressed: onTapWardrobe,
                  child: const Text('Pełna garderoba'),
                ),
            ],
          ),
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
