#!/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash
# Full Trener rebuild+install (PNG GLBs) — manual or via hook flag.
# Usage: touch /tmp/run-trener-rebuild.flag && bash scripts/rebuild-trener-png-install.sh
set -euo pipefail
exec /nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash /home/adam/.cursor/hooks/trener-rebuild-once.sh
