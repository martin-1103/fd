#!/bin/bash
# Error Analyzer CLI — query production errors from e.nuxhub.site
# Usage: ea.sh <command> [args...]

set -euo pipefail

BASE_URL="https://e.nuxhub.site"

die() {
  echo "{\"error\": \"$1\"}" >&2
  exit 1
}

require_id() {
  [ -n "${1:-}" ] || die "Missing error ID"
  [[ "$1" =~ ^[0-9]+$ ]] || die "Invalid error ID: $1 (must be numeric)"
}

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but not installed"
done

CMD="${1:-}"
[ -n "$CMD" ] || die "Usage: ea.sh <stats|show|update|plan|diff> [args...]"
shift

case "$CMD" in
  stats)
    RESPONSE=$(curl -sf "$BASE_URL/api/stats") || die "Failed to fetch stats"
    echo "$RESPONSE" | jq '{
      active_patterns: (.by_status | to_entries | map(select(.key != "merged" and .key != "discarded")) | map(.value) | add // 0),
      total_patterns,
      total_occurrences,
      by_status,
      by_severity,
      by_category,
      by_service,
      trend_7d
    }'
    ;;

  show)
    require_id "${1:-}"
    RESPONSE=$(curl -sf "$BASE_URL/api/errors/$1") || die "Error $1 not found"
    echo "$RESPONSE"
    ;;

  update)
    require_id "${1:-}"
    STATUS="${2:-}"
    [ -n "$STATUS" ] || die "Missing status. Valid: new, fixed, merged, discarded, regression"
    case "$STATUS" in
      new|fixed|merged|discarded|regression) ;;
      *) die "Invalid status: $STATUS. Valid: new, fixed, merged, discarded, regression" ;;
    esac
    RESPONSE=$(curl -sf -X PATCH \
      -H "Content-Type: application/json" \
      -d "{\"status\":\"$STATUS\"}" \
      "$BASE_URL/api/errors/$1/status") || die "Failed to update error $1"
    echo "$RESPONSE" | jq '.'
    ;;

  plan)
    require_id "${1:-}"
    RESPONSE=$(curl -sf "$BASE_URL/api/errors/$1/plan") || die "No fix plan found for error $1"
    echo "$RESPONSE"
    ;;

  diff)
    require_id "${1:-}"
    RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/errors/$1/fix-diff")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    if [ "$HTTP_CODE" = "404" ]; then
      echo "{\"info\": \"No applied fix diff available for error $1\"}"
    elif [ "$HTTP_CODE" != "200" ]; then
      die "Failed to fetch diff for error $1 (HTTP $HTTP_CODE)"
    else
      echo "$BODY"
    fi
    ;;

  *)
    die "Unknown command: $CMD. Valid: stats, show, update, plan, diff"
    ;;
esac
