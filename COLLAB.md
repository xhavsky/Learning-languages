# Współpraca: Tata + Anielka

## Katalogi

| Ścieżka | Rola |
|---------|------|
| `~/Dokumenty/Projekty/Learning-languages` | **Shared** — wspólny kod, portal WWW, agent, release |
| `~/Dokumenty/Projekty/Learning-languages-wip` | **WIP taty** — eksperymenty (`adam/wip`), nie idzie w paczki Anielki |

Portal (`anielka-portal`, port **7474**) zawsze celuje w **shared**.

## Anielka (WWW — publiczny Funnel)

1. **https://nixos.tail4caf1.ts.net:7475** — działa z Opera **bez Tailscale**
2. PIN: `3141` (w aplikacji / u taty)
3. Paczki / Release + Opublikuj na moje GitHub — w portalu

Persist: `systemctl --user enable --now anielka-portal-serve` (Funnel HTTPS :7475).

## Tata

- Codzienna praca / agent z portalu: **shared**
- Ryzykowne eksperymenty: otwórz **Learning-languages-wip**
- Z WIP → shared: cherry-pick / PR / ręczne skopiowanie — nie mieszaj dirty tree przy release

## Release

Przycisk w portalu: `git push origin main` + `gh workflow run` (`windows.yml` / `android.yml`).  
Wymaga czystego Gita w shared i dostępu do GitHub z PC taty.
