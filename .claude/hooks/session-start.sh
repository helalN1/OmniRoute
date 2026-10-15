#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: provisions a supported Node
# runtime, installs dependencies (incl. Husky hooks) and ensures a local .env.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

# engines.node is ">=22.22.2 <23 || >=24 <27"; the container image ships an
# older 22.x, so pin the version from .node-version through nvm.
NODE_MAJOR="$(tr -d '[:space:]' < .node-version 2>/dev/null || echo 24)"
export NVM_DIR="${NVM_DIR:-/opt/nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  set +u
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install "$NODE_MAJOR" >/dev/null
  nvm use "$NODE_MAJOR" >/dev/null
  set -u
  NODE_BIN_DIR="$(dirname "$(nvm which "$NODE_MAJOR")")"
  export PATH="$NODE_BIN_DIR:$PATH"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"$NODE_BIN_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  fi
fi
echo "Using node $(node -v), npm $(npm -v)" >&2

# npm install (not ci) so the cached container layer is reused. Its postinstall
# creates .env from .env.example and `prepare` installs the Husky hooks.
npm install --no-audit --no-fund

# Fallback in case postinstall skipped the env sync. JWT_SECRET/API_KEY_SECRET
# stay blank on purpose: the server generates and persists them on first boot
# (src/instrumentation-node.ts::ensureSecrets).
if [ ! -f .env ]; then
  npm run env:sync
fi
