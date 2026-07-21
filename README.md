# Dialectium

Aplikacja do nauki słówek (Flutter): Linux · Android · iOS · Windows.

## Pobieranie

Gotowe paczki: **[Releases](https://github.com/xhavsky/Dialectium/releases)**

| Platforma | Plik |
|-----------|------|
| Windows | `Dialectium-Windows.zip` — [INSTALL-WINDOWS.md](INSTALL-WINDOWS.md) |
| Linux | `Dialectium-Linux.zip` — rozpakuj i `./dialectium` |
| Android | `Dialectium.apk` |

## Uruchomienie z kodu

```bash
nix-shell -p flutter --run 'flutter run -d linux'
# albo (NixOS, po instalacji pakietu):
dialectium
```

## Funkcje

- Pule słówek, import CSV, metody ABC / pisanie / zdania
- AI **na urządzeniu** (Bielik) — bez chmury
- XP, poziomy, maskotka, sklep, SRS
- Język UI: PL / EN / ES / RU · motywy kolorystyczne
- Audio offline EN/ES/RU (Piper)

## Budowa paczek (dla maintainerów)

```bash
./scripts/fetch_ondevice_models.sh --all
./scripts/build_apk.sh
./scripts/package_linux_with_llm.sh
./scripts/package_windows_with_llm.sh
```

CI na `main` buduje Windows / Linux / Android.

## Audio TTS

```bash
python3 scripts/generate_tts.py
```

## Spec 3D maskotki

[docs/MASCOT_3D_WEARABLES_SPEC.md](docs/MASCOT_3D_WEARABLES_SPEC.md)

## Skrypty Python (archiwum)

`legacy/`: starsze skrypty CLI.
