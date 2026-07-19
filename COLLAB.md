# Współpraca: Tata + Anielka

## Katalogi

| Ścieżka | Rola |
|---------|------|
| `~/Dokumenty/Projekty/Learning-languages` | **Shared** — wspólny kod, portal WWW, agent, release |
| `~/Dokumenty/Projekty/Learning-languages-wip` | **WIP taty** — eksperymenty (`adam/wip`), nie idzie w paczki Anielki |

Portal (`anielka-portal`, port **7474**) zawsze celuje w **shared**.

## Anielka (WWW + Tailscale)

1. **HTTPS (OperaGX):** https://nixos.tail4caf1.ts.net:7475  
2. HTTP: http://nixos.tail4caf1.ts.net:7474 · IP: http://100.68.72.119:7474  
3. PIN w aplikacji / u taty (`3141`)
4. Tailscale na FreeUnicorn musi być **Connected** (to samo konto)
5. Paczki / Release + Opublikuj na moje GitHub — w portalu

Serve: `systemctl --user enable --now anielka-portal-serve` (HTTP 7474 + HTTPS 7475).

## Tata

- Codzienna praca / agent z portalu: **shared**
- Ryzykowne eksperymenty: otwórz **Learning-languages-wip**
- Z WIP → shared: cherry-pick / PR / ręczne skopiowanie — nie mieszaj dirty tree przy release

## Release

Przycisk w portalu: `git push origin main` + `gh workflow run` (`windows.yml` / `android.yml`).  
Wymaga czystego Gita w shared i dostępu do GitHub z PC taty.
