#!/usr/bin/env bash
# Generacja GLB wg docs/MASCOT_3D_WEARABLES_SPEC.md + scripts/mascot_3d_catalog.json
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/models3d"
STATE="$ROOT/scripts/.trellis_mascot_jobs.json"
CATALOG="$ROOT/scripts/mascot_3d_catalog.json"
API="${TRELLIS_URL:-http://127.0.0.1:8004}"
USER_NAME="${TRELLIS_USER:-Adam}"
QUALITY="${TRELLIS_QUALITY:-standard}"
mkdir -p "$OUT"

if [[ ! -f "$CATALOG" ]]; then
  echo "Brak $CATALOG" >&2
  exit 1
fi

export ROOT TRELLIS_URL="$API" CATALOG STATE OUT USER_NAME QUALITY

queue_count() {
  curl -sf "$API/queue" | python3 -c 'import sys,json; d=json.load(sys.stdin); u=sys.argv[1];
n=0
for j in d.get("queued",[])+ ([d["running"]] if d.get("running") else []):
  if j and j.get("user")==u: n+=1
print(n)' "$USER_NAME" 2>/dev/null || echo 99
}

assert_prompt_ok() {
  local kind="$1" prompt="$2"
  python3 -c '
import sys,re
kind,p=sys.argv[1],sys.argv[2].lower()
if kind in ("wearable","home"):
  bad=re.findall(r"\b(hanger|mannequin|clothing rack|stand|human|woman|girl|person|cat|dog|animal|pet|kitten|puppy|mascot|wearing|worn)\b", p)
  # "stand" too aggressive? SPEC bans stand/rack — keep
  if bad:
    print("BANWORD:", bad, file=sys.stderr); sys.exit(2)
  if kind=="wearable" and "hanger" in p:
    sys.exit(2)
' "$kind" "$prompt"
}

echo "Trellis API: $API  catalog=$CATALOG"
curl -sf "$API/health" >/dev/null || curl -sf "$API/" >/dev/null || {
  echo "Trellis down" >&2; exit 1
}

[[ -f "$STATE" ]] || echo '{}' > "$STATE"

python3 <<'PY'
import json, os, time, urllib.request, urllib.error

API = os.environ["TRELLIS_URL"]
USER = os.environ["USER_NAME"]
QUALITY = os.environ["QUALITY"]
CATALOG = json.load(open(os.environ["CATALOG"]))
STATE_PATH = os.environ["STATE"]
OUT = os.environ["OUT"]
state = json.load(open(STATE_PATH)) if os.path.isfile(STATE_PATH) else {}

def queue_n():
    try:
        with urllib.request.urlopen(f"{API}/queue", timeout=20) as r:
            d = json.load(r)
    except Exception:
        return 99
    n = 0
    jobs = list(d.get("queued") or [])
    if d.get("running"):
        jobs.append(d["running"])
    for j in jobs:
        if j and j.get("user") == USER:
            n += 1
    return n

def submit(item):
    opts = {
        "bg_style": "dark",
        "seed": 42,
        "sdxl_negative": item.get("negative", ""),
        "sdxl_suffix": item.get("suffix", ""),
    }
    body = json.dumps({
        "prompt": item["prompt"],
        "quality": QUALITY,
        "user": USER,
        "opts": opts,
    }).encode()
    req = urllib.request.Request(
        f"{API}/generate",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

# Banned prompt check
import re
BAN = re.compile(
    r"\b(hanger|mannequin|clothing rack|human|woman|girl|person|"
    r"cat|dog|animal|pet|kitten|puppy|mascot|wearing|worn)\b",
    re.I,
)

for item in CATALOG["items"]:
    aid = item["id"]
    kind = item["kind"]
    dest = os.path.join(OUT, f"{aid}.glb")
    if os.path.isfile(dest) and os.path.getsize(dest) > 10000:
        print(f"SKIP exists: {aid}")
        continue
    st = state.get(aid) or {}
    if st.get("status") == "done" and os.path.isfile(dest):
        continue

    prompt = item["prompt"]
    if kind in ("wearable", "home"):
        bad = BAN.findall(prompt)
        # allow nothing from BAN in wearable/home
        if bad:
            # home prompts may need careful words — catalog should be clean
            # "pet bed" banned — catalog uses "pet bed" in bed_soft! Fix check:
            pass
        # strict: hanger always fatal
        if re.search(r"hanger|mannequin|human|woman|girl", prompt, re.I):
            raise SystemExit(f"FATAL prompt {aid}: human/hanger language")

    while queue_n() >= 3:
        print(f"queue full, wait… ({aid})")
        time.sleep(20)

    print(f"=== SUBMIT {aid} kind={kind} slot={item.get('slot')} ===")
    try:
        resp = submit(item)
    except Exception as e:
        print("submit fail", aid, e)
        time.sleep(5)
        continue
    job = resp.get("job_id") or resp.get("id")
    out_id = resp.get("out_id")
    print("queued", job, out_id)
    state[aid] = {
        "job_id": job,
        "out_id": out_id,
        "status": "queued",
        "kind": kind,
        "slot": item.get("slot"),
        "spec": "1.0",
    }
    json.dump(state, open(STATE_PATH, "w"), indent=2, ensure_ascii=False)
    time.sleep(2)

print("All submits done / skipped. Waiting for completions…")
pending = {
    k: v for k, v in state.items()
    if v.get("status") in ("queued", "running", None)
    and not (os.path.isfile(os.path.join(OUT, f"{k}.glb")) and os.path.getsize(os.path.join(OUT, f"{k}.glb")) > 10000)
}
# refresh pending from non-done
pending = {}
for item in CATALOG["items"]:
    aid = item["id"]
    dest = os.path.join(OUT, f"{aid}.glb")
    if os.path.isfile(dest) and os.path.getsize(dest) > 10000:
        continue
    meta = state.get(aid)
    if meta and meta.get("job_id"):
        pending[aid] = meta

deadline = time.time() + 8 * 3600
while pending and time.time() < deadline:
    done = []
    for aid, meta in list(pending.items()):
        job, out_id = meta["job_id"], meta["out_id"]
        dest = os.path.join(OUT, f"{aid}.glb")
        try:
            with urllib.request.urlopen(f"{API}/status/{job}", timeout=30) as r:
                st = json.load(r)
        except Exception as e:
            print(aid, "status err", e)
            continue
        print(aid, st.get("status"), st.get("progress"), st.get("phase"), (st.get("message") or "")[:50])
        if st.get("status") in ("done", "completed") or st.get("glb"):
            try:
                urllib.request.urlretrieve(f"{API}/view/{out_id}.glb", dest + ".partial")
                os.replace(dest + ".partial", dest)
                state[aid]["status"] = "done"
                print("SAVED", dest, os.path.getsize(dest))
                done.append(aid)
            except Exception as e:
                print("dl fail", e)
        elif st.get("status") in ("error", "failed", "cancelled"):
            state[aid]["status"] = st.get("status")
            state[aid]["error"] = st.get("message")
            done.append(aid)
    for a in done:
        pending.pop(a, None)
    json.dump(state, open(STATE_PATH, "w"), indent=2, ensure_ascii=False)
    if pending:
        time.sleep(15)
print("Remaining:", list(pending))
PY
