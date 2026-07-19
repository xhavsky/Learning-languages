# Trener Językowy — Anielka

Flutter (Linux / Android / iOS / Windows) + archiwum skryptów Python w `legacy/`.

## Uruchomienie

```bash
trener-jezykowy          # NixOS
# albo:
nix-shell -p flutter --run 'flutter run -d linux'
```

## Funkcje (0.0.5)

- **Zestawy / kategorie tematyczne** — Czasowniki, Powitania, Jedzenie, Zwierzęta, Rodzina, Kolory…
- **Import CSV / tekst** — wklej lub plik (`pl,obcy` / `pl;obcy` / `pl - obcy`)
- **Codzienna rozmowa AI** — tylko lokalnie (Ollama/Bielik na PC); bez chmury; tryb offline bez Ollamy; +40 XP za 3 wiadomości/dzień
- **XP i poziomy** — punkty za odpowiedzi i rozmowy; **nagroda za lvl**: ciekawostka językowa + bonus XP
- **SRS** — poziomy 0–3, powtórki wg `nextDue`
- **Kierunek** PL→obcy / obcy→PL / mieszany + podpowiedź (pierwsza litera)
- Metoda **ABC** lub **Pisanie** (zapamiętana per język)
- Klawiatura cyrylicy (RU) i znaki hiszpańskie (á é ñ…)
- Audio offline EN/ES/RU (`scripts/generate_tts.py`, Piper) + tempo 0.75× / 1× / 1.25×
- **Motywy kolorystyczne**: Las / Ocean / Zachód / Winogrono / Róż / Grafit + jasny/ciemny
- Feedback **inline** (bez AlertDialog)
- Eksport / import bazy JSON (Ustawienia)
- **Portal Anielki** — czat z agentem + budowa paczek: [COLLAB.md](COLLAB.md) (jeden wspólny projekt)

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
