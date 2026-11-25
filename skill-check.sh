#!/bin/sh
# pwnry skill check: look up an agent skill directory in the public Pwnry Skill Registry.
#
#   sh skill-check.sh [--fail-on findings|unknown] [--quiet] SKILL_DIR...
#
# The directory's content hash is computed locally; only that hash is sent.
# Exit codes: 0 ok, 1 policy failure (--fail-on), 2 usage or network error.
set -eu

API="${PWNRY_API:-https://pwnry.ai}"
FAIL_ON=""
QUIET=0

usage() {
  echo "usage: skill-check.sh [--fail-on findings|unknown] [--quiet] SKILL_DIR..." >&2
  exit 2
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

# Same hash as the registry: one "sha256  path" line per file, sorted bytewise.
content_hash() {
  (cd "$1" && find . -type f ! -path './.git/*' | sed 's|^\./||' | LC_ALL=C sort |
    while IFS= read -r f; do sha256 "$f"; done) | sha256 | cut -d' ' -f1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fail-on) [ $# -ge 2 ] || usage; FAIL_ON="$2"; shift 2 ;;
    --fail-on=*) FAIL_ON="${1#--fail-on=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || usage
case "$FAIL_ON" in ""|findings|unknown) ;; *) usage ;; esac
command -v curl >/dev/null 2>&1 || { echo "skill-check: curl is required" >&2; exit 2; }

status=0
for dir in "$@"; do
  if [ ! -f "$dir/SKILL.md" ]; then
    echo "skill-check: $dir has no SKILL.md" >&2
    exit 2
  fi
  hash=$(content_hash "$dir")
  body=$(curl -fsS --max-time 20 "$API/api/public/skill-registry/lookup?content_hash=$hash") || {
    echo "skill-check: registry lookup failed" >&2
    exit 2
  }

  case "$body" in
    *'"matches":[]'*)
      [ "$QUIET" = 1 ] || echo "$dir: unknown to the registry (content hash $hash). Check it at $API/skill-checks"
      [ "$FAIL_ON" = unknown ] && status=1
      ;;
    *)
      count=$(printf '%s' "$body" | sed -n 's/.*"finding_count":\([0-9]*\).*/\1/p' | head -n 1)
      url=$(printf '%s' "$body" | sed -n 's/.*"report_url":"\([^"]*\)".*/\1/p' | head -n 1)
      if [ "${count:-0}" -gt 0 ]; then
        echo "$dir: $count finding(s) in the registry report $url"
        [ -n "$FAIL_ON" ] && status=1
      else
        [ "$QUIET" = 1 ] || echo "$dir: no findings in the checked scope. Report: $url"
      fi
      ;;
  esac
done
exit "$status"
