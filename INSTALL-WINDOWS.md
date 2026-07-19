# Windows — jak zainstalować (Anielka)

## Najprościej

1. Wejdź na: https://github.com/xhavsky/Learning-languages/releases
2. Pobierz **Trener-Jezykowy-Windows.zip**
3. Rozpakuj (np. na Pulpit)
4. Kliknij dwukrotnie **trener_jezykowy.exe**

Jeśli Windows pokaże niebieski ekran „Windows ochronił komputer”:
**Więcej informacji** → **Uruchom mimo to**.

**Nic nie instaluj ręcznie.** W ZIP jest AI (Bielik 1.5B + Ollama). Przy pierwszym uruchomieniu z internetem apka **sama** dociągnie pełnego Bielika 11B — bez klikania. Bez netu od razu działa na 1.5B.

## Co jest w środku

- `trener_jezykowy.exe` — gra / nauka słówek
- folder `data/` — baza słówek i audio
- `models/` — Bielik GGUF (1.5B + 11B v3)
- `bundled/ollama/ollama.exe` — lokalna Ollama
- pozostałe pliki `.dll` — potrzebne do działania (nie usuwać)

## Rozmowa AI

- Od razu: Bielik **1.5B v3** z paczki (offline).
- Z internetem (raz): apka sama dociągnie Bielik **11B v3** przez Ollamę w tle.
- Pendrive z pełnym 11B offline: tata składa `package_windows_with_llm.sh`.
