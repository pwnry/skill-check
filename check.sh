#!/usr/bin/env bash
# Submits skill directories for a full Pwnry Skill Check and waits for the results.
# Free for public repositories (4 checks per repository and month); needs
# `permissions: id-token: write` for the GitHub Actions OIDC token.
set -euo pipefail

API="${PWNRY_API:-https://pwnry.ai}"
FAIL_ON="${INPUT_FAIL_ON:-}"
PUBLISH="${INPUT_PUBLISH:-false}"
WAIT_SECONDS="${INPUT_TIMEOUT_SECONDS:-1200}"

if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  echo "::error::check: true needs 'permissions: id-token: write' in the workflow."
  exit 2
fi

oidc_token() {
  curl -fsS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://pwnry.ai" | jq -r .value
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
status=0

for dir in "$@"; do
  if [ ! -f "$dir/SKILL.md" ]; then
    echo "::error::$dir has no SKILL.md"
    exit 2
  fi
  skill=$(basename "$(cd "$dir" && pwd)")
  path=$(realpath --relative-to="${GITHUB_WORKSPACE:-$PWD}" "$dir")
  zip="$workdir/$skill.zip"
  rm -f "$zip"
  (cd "$dir" && find . -type f ! -path './.git/*' | sed 's|^\./||' | LC_ALL=C sort | zip -q -X -@ "$zip")
  query="skill=$(jq -rn --arg v "$skill" '$v|@uri')&path=$(jq -rn --arg v "$path" '$v|@uri')"
  if [ "$PUBLISH" = "true" ]; then query="$query&publish=1"; fi

  response=$(curl -sS -w '\n%{http_code}' -X POST \
    -H "Authorization: Bearer $(oidc_token)" -H "Content-Type: application/zip" \
    --data-binary @"$zip" "$API/api/public/skill-checks/github?$query")
  code=$(printf '%s' "$response" | tail -n 1)
  body=$(printf '%s' "$response" | sed '$d')

  case "$code" in
    201) ;;
    402|429)
      echo "::warning::$dir: $(printf '%s' "$body" | jq -r .message). Falling back to a registry lookup."
      sh "$GITHUB_ACTION_PATH/skill-check.sh" ${FAIL_ON:+--fail-on "$FAIL_ON"} "$dir" || status=1
      continue
      ;;
    *)
      echo "::error::$dir: submission failed ($code): $(printf '%s' "$body" | jq -r '.message // .error // .' 2>/dev/null)"
      exit 2
      ;;
  esac

  id=$(printf '%s' "$body" | jq -r .id)
  secret=$(printf '%s' "$body" | jq -r .token)
  echo "$dir: submitted ($(printf '%s' "$body" | jq -r .quota.remaining) free checks left this month)"

  deadline=$((SECONDS + WAIT_SECONDS))
  while :; do
    result=$(curl -fsS -H "Authorization: Bearer $secret" "$API/api/public/skill-checks/github/$id")
    state=$(printf '%s' "$result" | jq -r .status)
    if [ "$state" = completed ] || [ "$state" = failed ]; then break; fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "::error::$dir: no result after ${WAIT_SECONDS}s"
      exit 2
    fi
    sleep 10
  done

  count=$(printf '%s' "$result" | jq '.findings | length')
  echo "$dir: $(printf '%s' "$result" | jq -r '.verdict // .outcome') with $count finding(s). Report: $(printf '%s' "$result" | jq -r .report_url)"
  printf '%s' "$result" | jq -r '.findings[] | "  \(.severity)\t\(.code)\t\(.path // "")"'
  if [ "$count" -gt 0 ] && [ -n "$FAIL_ON" ]; then status=1; fi
  if [ "$state" = failed ] && [ "$FAIL_ON" = unknown ]; then status=1; fi
done

exit "$status"
