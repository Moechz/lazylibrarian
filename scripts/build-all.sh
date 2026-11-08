#!/bin/bash
# ===========================================================================
# Build the TOS 7 Docker application package for every architecture declared in
# ./tosapp.json ("platforms"; falls back to the single "platform").
#
#   scripts/build-all.sh               -> out/<appid>_x86_64.tar.gz
#                                         out/<appid>_aarch64.tar.gz  (+ .sha256)
#   scripts/build-all.sh 3.0.1-2       -> same, with a new packaging iteration
#
# Why the architecture suffix: the official Docker development guide (§9.5)
# states that a Docker application cannot declare more than one architecture -
# "for multi-architecture support, each target architecture must be submitted
# as a separate build, and the package file name must include the appropriate
# architecture suffix". `scripts/build.sh` itself stays single-platform and
# architecture-neutral, so a single-architecture project keeps producing
# out/<appid>.tar.gz.
#
# Every build runs tools/verify.py (the review-standards gate) and the official
# TOSAppSelfTestingTool -c check before its artifact is accepted.
# ===========================================================================
set -euo pipefail

cd "$(dirname "$0")/.."
APPID=$(python3 -c "import json;print(json.load(open('tosapp.json'))['app_id'])")
VERSION="${1:-$(python3 -c "import json;print(json.load(open('tosapp.json'))['version'])")}"
PLATFORMS=$(python3 - <<'PY'
import json
s = json.load(open("tosapp.json"))
print(" ".join(s.get("platforms") or [s["platform"]]))
PY
)

echo ">> $APPID $VERSION for: $PLATFORMS"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for plat in $PLATFORMS; do
  echo
  echo "== build $plat"
  bash scripts/build.sh "$VERSION" "$plat"
  mv "out/${APPID}.tar.gz" "${TMP}/${APPID}_${plat}.tar.gz"
  echo "== official check $plat"
  ./TOSAppSelfTestingTool -c "${TMP}/${APPID}_${plat}.tar.gz"
done

# scripts/build.sh wipes ./out on every run, so the artifacts are collected in a
# temporary directory first and published here only after all builds passed.
rm -rf out
mkdir -p out
for f in "$TMP"/*.tar.gz; do
  base=$(basename "$f")
  cp "$f" "out/$base"
  ( cd out && sha256sum "$base" > "$base.sha256" )
done

# build.sh keeps ./tosapp.json in sync with the last build; restore the version
# that was asked for and the primary platform (the first of "platforms").
python3 - "$VERSION" <<'PY'
import json, pathlib, sys
p = pathlib.Path("tosapp.json")
spec = json.loads(p.read_text(encoding="utf-8"))
spec["version"] = sys.argv[1]
spec["platform"] = (spec.get("platforms") or [spec["platform"]])[0]
p.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo
echo ">> artifacts:"
ls -la out
