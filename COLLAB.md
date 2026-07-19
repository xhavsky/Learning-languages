# Współpraca: Tata + Anielka

## Katalogi

| Ścieżka | Rola |
|---------|------|
| `~/Dokumenty/Projekty/Learning-languages` | **Shared** — wspólny kod, portal WWW, agent, release |
| `~/Dokumenty/Projekty/Learning-languages-wip` | **WIP taty** — eksperymenty (`adam/wip`), nie idzie w paczki Anielki |

Portal (`anielka-portal`, port **7474**) zawsze celuje w **shared**.

## Anielka (WWW + Tailscale)

1. http://nixos.tail4caf1.ts.net:7474 (PIN w aplikacji / u taty)
2. Pisze prośby → Cursor Agent edytuje **shared**
3. **Paczki / Release** → Windows ZIP i/lub APK (GitHub Actions)
4. Opcjonalnie: **Opublikuj na moje GitHub** (jej token `repo`)

## Tata

- Codzienna praca / agent z portalu: **shared**
- Ryzykowne eksperymenty: otwórz **Learning-languages-wip**
- Z WIP → shared: cherry-pick / PR / ręczne skopiowanie — nie mieszaj dirty tree przy release

## Release

Przycisk w portalu: `git push origin main` + `gh workflow run` (`windows.yml` / `android.yml`).  
Wymaga czystego Gita w shared i dostępu do GitHub z PC taty.
