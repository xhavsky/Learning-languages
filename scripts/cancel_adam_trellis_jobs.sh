#!/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash
# Anuluje wszystkie joby Adama w Trellis (:8004)
set -euo pipefail
API="http://127.0.0.1:8004"
CURL="/run/current-system/sw/bin/curl"
PYTHON="/nix/store/mj8b2zc2i4f77ak89k1fckgs40dqa09n-python3-3.13.13-env/bin/python3"

QUEUE="$($CURL -sf "$API/queue")"
echo "$QUEUE" | $PYTHON -c "
import json,sys,subprocess,os
d=json.load(sys.stdin)
api=os.environ.get('API','http://127.0.0.1:8004')
curl=os.environ['CURL']
ids=set(['668d63caa5204bf9','c748029a22364e57','aa1fe884e5f34155'])
for j in d.get('queued',[]):
    if j and j.get('user')=='Adam':
        ids.add(j.get('job_id') or j.get('id'))
r=d.get('running')
if r and r.get('user')=='Adam':
    ids.add(r.get('job_id') or r.get('id'))
for jid in sorted(x for x in ids if x):
    p=subprocess.run([curl,'-sf','-X','POST',f'{api}/cancel/{jid}',
        '-H','Content-Type: application/json','-d','{\"user\":\"Adam\"}'],
        capture_output=True,text=True)
    print(jid, p.stdout or p.stderr or p.returncode)
"

echo "=== queue after ==="
$CURL -sf "$API/queue" | $PYTHON -m json.tool
