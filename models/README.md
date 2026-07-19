# Modele lokalne (gitignore *.gguf)

| Plik | Rola |
|------|------|
| `Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf` | Zawsze w APK / ZIP (~1 GB) |
| `Bielik-11B-v3.0-Instruct.Q4_K_M.gguf` | Pełny offline PC (USB / `package_*_with_llm.sh`) |

```bash
./scripts/fetch_ondevice_models.sh --all
./scripts/build_apk.sh                  # telefon: model W APK
./scripts/package_windows_with_llm.sh   # PC: pełny offline ZIP
```

Użytkownik końcowy nie odpala tych skryptów — dostaje gotową paczkę.
