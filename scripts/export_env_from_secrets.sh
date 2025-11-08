#!/usr/bin/env bash
# Export a set of expected secrets from the environment into an env file
# Usage: ./scripts/export_env_from_secrets.sh path/to/envfile

set -euo pipefail

OUT=${1:-env/.env}
DIR=$(dirname "$OUT")
mkdir -p "$DIR"

vars=(
  SUPABASE_URL
  SUPABASE_KEY
  STRIPE_PUBLISHABLE_KEY
  STRIPE_SECRET_KEY
  SENTRY_DSN
  FIREBASE_CONFIG_JSON
  FLUTTER_ENV
)

lines=()
for v in "${vars[@]}"; do
  val="${!v:-}"
  if [ -n "$val" ]; then
    # Quote values to preserve newlines/spaces
    printf '%s="%s"\n' "$v" "$val" >> "$OUT"
  fi
done

if [ ! -s "$OUT" ]; then
  echo "No known env vars found in environment; $OUT is empty" >&2
  exit 1
fi

echo "Wrote $OUT from environment variables (not committed)."
