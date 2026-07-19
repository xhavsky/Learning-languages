# Trener Językowy — Anielka

Flutter (Linux / Android / iOS / Windows) + archiwum skryptów Python w `legacy/`.

## Uruchomienie

```bash
trener-jezykowy          # NixOS
# albo:
nix-shell -p flutter --run 'flutter run -d linux'
```

## Funkcje (0.0.10)

- **Własne pule słówek** — na ekranie ćwiczeń wybierz pulę (Cała baza / Nieopanowane / Trudne / Twoja) albo utwórz nową („Nowa pula”); edycja też w ikonie folderu
- **Import CSV / tekst** — wklej lub plik (`pl,obcy` / `pl;obcy` / `pl - obcy`)
- **Codzienna rozmowa AI** — prawdziwy LLM **na urządzeniu użytkownika** (bez portalu/chmury):
  - **PC:** Bielik **11B v3** przez Ollamę (sidecar w paczce albo systemowa) → fallback GGUF 1.5B
  - **Telefon:** Bielik **1.5B v3** (GGUF / llama.cpp)
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

## 3D maskotki

Spec: [docs/MASCOT_3D_WEARABLES_SPEC.md](docs/MASCOT_3D_WEARABLES_SPEC.md).

## Lokalne modele (Bielik v3) — dla buildera, nie dla Anielki

Użytkownik końcowy **nic nie ściąga**: modele są w APK / ZIP.

Builder (raz przed releasem):

```bash
./scripts/fetch_ondevice_models.sh --all          # cache lokalny
./scripts/build_apk.sh                             # APK z 1.5B w środku
./scripts/package_linux_with_llm.sh                # Linux ZIP z 11B + Ollama
./scripts/package_windows_with_llm.sh              # Windows ZIP (po flutter build windows)
```

CI na `main` też pakuje modele do artefaktów (cache HuggingFace).

## Regeneracja audio

```bash
python3 scripts/generate_tts.py
```

## Android / Windows

```bash
./scripts/build_apk.sh          # → dist/trener-jezykowy.apk (+ GGUF jeśli pobrany)
```

**Windows:** [Releases](https://github.com/xhavsky/Learning-languages/releases) → `Trener-Jezykowy-Windows.zip` — [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md). Pełna paczka z AI w środku.

**Android:** ten sam Releases → `trener-jezykowy.apk` (Bielik 1.5B v3 wbudowany; przy 1. rozmowie wypakuje się sam).

## Skrypty Python (archiwum)

`legacy/`: `uczenie sie słówek.py`, `nauka abc.py`, `abc+pisanie.py`
