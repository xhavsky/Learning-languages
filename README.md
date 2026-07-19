# Trener Językowy — Anielka

Flutter (Linux / Android / iOS) + skrypty Python (tkinter) Anielki.

## Uruchomienie Flutter

```bash
trener-jezykowy          # NixOS (po install)
# albo:
nix-shell -p flutter --run 'flutter run -d linux'
```

Funkcje:
- HiDPI + tryb ciemny
- Metoda **Wybór ABC** lub **Wpisywanie** (jak w `abc+pisanie.py`)
- Klawiatura **cyrylicy** dla Rosyjskiego
- Audio offline (`assets/audio/`, generacja: `scripts/generate_tts.py`)
- Bazy: Angielski, Hiszpański, Rosyjski (cyrylica)

## Skrypty Python Anielki

Zachowane w katalogu głównym i w `legacy/`:
- `uczenie sie słówek.py` — klasyczny trener
- `nauka abc.py` — rosyjski + klawiatura
- `abc+pisanie.py` — ABC + pisanie + cyrylica

```bash
python3 "abc+pisanie.py"
```

## Android / iOS

```bash
./scripts/build_apk.sh          # → dist/trener-jezykowy.apk
# iOS: ios/ + .github/workflows/ios.yml (wymaga macOS)
```

## Regeneracja audio

```bash
python3 scripts/generate_tts.py
```
