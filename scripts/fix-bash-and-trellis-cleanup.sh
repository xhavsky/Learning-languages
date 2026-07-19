#!/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash
# Fix missing system bash + run Trellis mascot cleanup.
# Run from GNOME Terminal: bash scripts/fix-bash-and-trellis-cleanup.sh
set -euo pipefail

echo "=== 1/2 nixos-rebuild (adds bash+curl to system PATH) ==="
sudo nixos-rebuild switch --flake "$HOME/.nixos-config#nixos"

echo "=== 2/2 Trellis cleanup ==="
touch /tmp/run-trellis-cleanup.flag
/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash \
  /home/adam/Dokumenty/Projekty/Learning-languages/.cursor/hooks/trellis-cleanup.sh

echo "=== Report ==="
cat /tmp/trellis-cleanup-report.json
