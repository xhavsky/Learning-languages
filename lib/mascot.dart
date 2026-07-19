import 'package:flutter/material.dart';

/// Ubranko / akcesorium odblokowywane za poziom.
class MascotItem {
  const MascotItem({
    required this.id,
    required this.unlockLevel,
    required this.name,
    required this.emoji,
    required this.blurb,
  });

  final String id;
  final int unlockLevel;
  final String name;
  final String emoji;
  final String blurb;
}

/// Sklepik kotka — za każdy nowy poziom nowe ciuszki.
const mascotWardrobe = <MascotItem>[
  MascotItem(
    id: 'bow',
    unlockLevel: 2,
    name: 'Kokardka',
    emoji: '🎀',
    blurb: 'Różowa kokardka — stylowa od razu!',
  ),
  MascotItem(
    id: 'scarf',
    unlockLevel: 3,
    name: 'Szalik',
    emoji: '🧣',
    blurb: 'Ciepły szalik na powtórki w chłodne dni.',
  ),
  MascotItem(
    id: 'hat',
    unlockLevel: 4,
    name: 'Czapeczka',
    emoji: '🎩',
    blurb: 'Elegancka czapka jak u prawdziwej pani kotki.',
  ),
  MascotItem(
    id: 'glasses',
    unlockLevel: 5,
    name: 'Okulary',
    emoji: '🤓',
    blurb: 'Mądre okulary do czytania słówek.',
  ),
  MascotItem(
    id: 'collar',
    unlockLevel: 6,
    name: 'Obroża z dzwonkiem',
    emoji: '🔔',
    blurb: 'Dzwoneczek — słychać, że uczy się!',
  ),
  MascotItem(
    id: 'cape',
    unlockLevel: 8,
    name: 'Pelerynka',
    emoji: '🦸',
    blurb: 'Superbohaterka języków!',
  ),
  MascotItem(
    id: 'crown',
    unlockLevel: 10,
    name: 'Korona',
    emoji: '👑',
    blurb: 'Królowa passy i XP.',
  ),
  MascotItem(
    id: 'backpack',
    unlockLevel: 12,
    name: 'Plecaczek',
    emoji: '🎒',
    blurb: 'Na wycieczki ze słówkami.',
  ),
  MascotItem(
    id: 'star',
    unlockLevel: 15,
    name: 'Gwiazdka',
    emoji: '⭐',
    blurb: 'Świecisz jak gwiazda Treningu.',
  ),
  MascotItem(
    id: 'wings',
    unlockLevel: 20,
    name: 'Skrzydełka',
    emoji: '🪽',
    blurb: 'Leci na level MAX!',
  ),
];

const mascotDailyFeedGoal = 3;

MascotItem? mascotItemForLevel(int level) {
  for (final item in mascotWardrobe) {
    if (item.unlockLevel == level) return item;
  }
  return null;
}

List<MascotItem> unlockedMascotItems(int playerLevel) {
  return [
    for (final item in mascotWardrobe)
      if (playerLevel >= item.unlockLevel) item,
  ];
}

/// Widget kotka z nakładkami ubranek + statusem karmienia.
class MascotCard extends StatelessWidget {
  const MascotCard({
    super.key,
    required this.playerLevel,
    required this.wordsToday,
    required this.fedToday,
    this.compact = false,
    this.onTapWardrobe,
  });

  final int playerLevel;
  final int wordsToday;
  final bool fedToday;
  final bool compact;
  final VoidCallback? onTapWardrobe;

  @override
  Widget build(BuildContext context) {
    final items = unlockedMascotItems(playerLevel);
    final need = (mascotDailyFeedGoal - wordsToday).clamp(0, mascotDailyFeedGoal);
    final hungerLabel = fedToday
        ? 'Syta i szczęśliwa! (+nauka dziś ✓)'
        : need == 0
            ? 'Już najedzona — możesz dalej ćwiczyć.'
            : 'Głodna… nakarm nauką: jeszcze $need słówk${need == 1 ? 'o' : 'a'} dziś';

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
                    SizedBox(
                      height: compact ? 140 : 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/kitten_book.png',
                              fit: BoxFit.contain,
                              height: compact ? 140 : 220,
                            ),
                          ),
                          // Ubranka jako emoji wokół kotka
                          if (items.isNotEmpty)
                            Positioned(
                              top: 4,
                              left: 8,
                              right: 8,
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  for (final it in items.take(6))
                                    Text(it.emoji, style: const TextStyle(fontSize: 22)),
                                ],
                              ),
                            ),
                          if (!fedToday)
                            Positioned(
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                      .withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Miaaa… jem słówka!',
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                              ),
                            ),
                        ],
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
                  ],
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Garderoba (${items.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final it in items)
                  Chip(
                    avatar: Text(it.emoji),
                    label: Text(it.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Awansuj na poziom 2 — Kicia dostanie pierwsze ubranko!',
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
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}
