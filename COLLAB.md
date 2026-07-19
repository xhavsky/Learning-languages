# Współpraca: Anielka + Tata

To jest **projekt Anielki**. Jeden katalog, jedna gałąź `main`, wspólna praca.

## Gdzie jest kod

`~/Dokumenty/Projekty/Learning-languages`  
GitHub: https://github.com/xhavsky/Learning-languages

Nie ma osobnego „WIP taty” — tata i Anielka pracują nad tym samym.

## Jak pracujecie

| Kto | Jak |
|-----|-----|
| **Anielka** | Portal WWW → pisze, co zmienić → asystent edytuje ten sam projekt → może odpalić paczki (Windows/APK) |
| **Tata** | Ten sam folder w Cursorze / edytorze — te same pliki, ten sam `main` |

Portal: **https://nixos.tail4caf1.ts.net:7475** · PIN u taty / w aplikacji.

## Paczki (Releases)

1. Anielka klika w portalu **Windows ZIP** / **Android APK**
2. GitHub buduje aplikację w chmurze
3. Gotowy plik: https://github.com/xhavsky/Learning-languages/releases

Żeby build wystartował, zmiany w projekcie muszą być zapisane w Gicie (commit). Asystent z portalu albo tata mogą to zrobić.

## Serwis na PC taty

```bash
systemctl --user enable --now anielka-portal.service
systemctl --user enable --now anielka-portal-serve.service   # Funnel :7475
```
