#!/usr/bin/env bash
set -euo pipefail

MODE="text"
STRICT=0

for arg in "$@"; do
  case "$arg" in
    --json)
      MODE="json"
      ;;
    --strict)
      STRICT=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: validate-tooling [--strict] [--json]

Options:
  --strict   Return non-zero if any optional check fails (in addition to required).
  --json     Emit machine-readable JSON summary.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

# All manifest tools are required. Exit 1 if any are missing.
REQUIRED_TOOLS=(
  java javac dotnet python3 pip uv
  node npm pnpm yarn deno bun
  rustc cargo go gcc g++ clang cmake
  mvn gradle bazel protoc
  psql mysql mongosh redis-cli sqlite3
  pi playwright
)

PASS=0
FAIL=0
WARN=0

CHECK_RESULTS=""

append_result() {
  # status|name|message
  CHECK_RESULTS+="$1|$2|$3"$'\n'
}

check_cmd() {
  local name="$1"
  local required="$2"

  if command -v "$name" >/dev/null 2>&1; then
    local version
    version="$($name --version 2>/dev/null | head -n1 || true)"
    append_result "ok" "$name" "${version:-found}"
    PASS=$((PASS + 1))
  else
    if [[ "$required" == "required" ]]; then
      append_result "fail" "$name" "missing"
      FAIL=$((FAIL + 1))
    else
      append_result "warn" "$name" "missing (optional)"
      WARN=$((WARN + 1))
    fi
  fi
}

check_models_json() {
  local models="${HOME}/.pi/agent/models.json"
  if [[ ! -f "$models" ]]; then
    append_result "warn" "models.json" "not found at ${models}"
    WARN=$((WARN + 1))
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    if jq empty "$models" >/dev/null 2>&1; then
      append_result "ok" "models.json" "valid JSON"
      PASS=$((PASS + 1))
    else
      append_result "fail" "models.json" "invalid JSON"
      FAIL=$((FAIL + 1))
      return 1
    fi

    # Reachability checks for provider baseUrl values.
    local urls
    urls=$(jq -r '.providers // {} | to_entries[]? | .value.baseUrl // empty' "$models")

    if [[ -z "$urls" ]]; then
      append_result "warn" "provider-baseUrl" "no provider baseUrl entries found"
      WARN=$((WARN + 1))
      return 0
    fi

    while IFS= read -r url; do
      [[ -z "$url" ]] && continue
      if curl -fsS --max-time 3 "$url/models" >/dev/null 2>&1 || curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
        append_result "ok" "provider-reachability" "reachable: $url"
        PASS=$((PASS + 1))
      else
        append_result "warn" "provider-reachability" "unreachable: $url"
        WARN=$((WARN + 1))
      fi
    done <<< "$urls"
  else
    append_result "warn" "jq" "missing; cannot validate models.json format"
    WARN=$((WARN + 1))
  fi
}

for cmd in "${REQUIRED_TOOLS[@]}"; do
  check_cmd "$cmd" "required"
done

check_settings_json() {
  local settings="${HOME}/.pi/agent/settings.json"
  if [[ ! -f "$settings" ]]; then
    append_result "warn" "settings.json" "not found at ${settings}"
    WARN=$((WARN + 1))
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    if jq empty "$settings" >/dev/null 2>&1; then
      append_result "ok" "settings.json" "valid JSON"
      PASS=$((PASS + 1))
    else
      append_result "fail" "settings.json" "invalid JSON"
      FAIL=$((FAIL + 1))
    fi
  fi
}

check_models_json || true
check_settings_json || true

if [[ "$MODE" == "json" ]]; then
  if command -v jq >/dev/null 2>&1; then
    # Build JSON payload from newline-delimited records.
    while IFS='|' read -r status name message; do
      [[ -z "${status}" ]] && continue
      printf '%s\n' "{\"status\":\"$status\",\"name\":\"$name\",\"message\":\"${message//\"/\\\"}\"}"
    done <<< "$CHECK_RESULTS" | jq -s --argjson pass "$PASS" --argjson fail "$FAIL" --argjson warn "$WARN" '{summary:{pass:$pass,fail:$fail,warn:$warn},checks:.}'
  else
    echo '{"error":"jq is required for --json output"}'
    exit 2
  fi
else
  echo "== validate-tooling summary =="
  echo "PASS: $PASS"
  echo "FAIL: $FAIL"
  echo "WARN: $WARN"
  echo

  while IFS='|' read -r status name message; do
    [[ -z "${status}" ]] && continue
    printf '[%s] %s - %s\n' "$status" "$name" "$message"
  done <<< "$CHECK_RESULTS"
fi

if (( FAIL > 0 )); then
  exit 1
fi

if (( STRICT == 1 && WARN > 0 )); then
  exit 1
fi

exit 0
