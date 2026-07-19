# Trener Językowy — Anielka

Flutter (Linux / Android / iOS / Windows) + archiwum skryptów Python w `legacy/`.

## Uruchomienie

```bash
trener-jezykowy          # NixOS
# albo:
nix-shell -p flutter --run 'flutter run -d linux'
```

## Funkcje (0.0.8)

- **Zestawy / kategorie tematyczne** — pasek do przesuwania na ekranie głównym
- **Import CSV / tekst** — wklej lub plik (`pl,obcy` / `pl;obcy` / `pl - obcy`)
- **Codzienna rozmowa AI** — model językowy **na urządzeniu** (wbudowany tutor; opcjonalnie lokalna Ollama). Bez portalu i chmury; +40 XP za 3 wiadomości/dzień
- **XP i poziomy** — punkty za odpowiedzi i rozmowy; im wyższy lvl, tym więcej XP trzeba; **nagroda za lvl**: tytuł + ciekawostka (💡) + losowe ubranko Kici + bonus XP + złote łapki; album odblokowanych nagród
- **Maskotka Kicia** — kreskówka na przezroczystym tle; karm nauką (min. 5 słówek dziennie); garderoba + **sklep** (miski, posłanie, ekskluzywne ubranka za złote łapki 🐾)
- **Złote łapki** — waluta: +1 za poprawną odpowiedź, +3 gdy Kicia najedzona, +5 za poziom, +2 za rozmowę AI
- **SRS** — poziomy 0–3, powtórki wg `nextDue`
- **Kierunek** PL→obcy / obcy→PL / mieszany + podpowiedź (pierwsza litera)
- Metoda **ABC** lub **Pisanie** (zapamiętana per język)
- Klawiatura cyrylicy (RU) i znaki hiszpańskie (á é ñ…)
- Audio offline EN/ES/RU (`scripts/generate_tts.py`, Piper) + tempo 0.75× / 1× / 1.25×
- **Motywy kolorystyczne**: Las / Ocean / Zachód / Winogrono / Róż / Grafit + jasny/ciemny
- Feedback **inline** (bez AlertDialog)
- Eksport / import bazy JSON (Ustawienia)
- **Portal współpracy** — współpraca + budowa paczek: [COLLAB.md](COLLAB.md) (jeden wspólny projekt)

## Regeneracja audio

```bash
python3 scripts/generate_tts.py
```

## Android / Windows

```bash
./scripts/build_apk.sh          # → dist/trener-jezykowy.apk
```

**Windows:** [Releases](https://github.com/xhavsky/Learning-languages/releases) → `Trener-Jezykowy-Windows.zip` — [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md).

**Android:** ten sam Releases → `trener-jezykowy.apk` (workflow APK).

## Skrypty Python (archiwum)

`legacy/`: `uczenie sie słówek.py`, `nauka abc.py`, `abc+pisanie.py`
