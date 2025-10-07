#!/usr/bin/env bash
set -euo pipefail

# ==== PARAMÈTRES (venant de Jenkins) ====
: "${AZURE_TENANT1_ID:?missing}"
: "${AZURE_CLIENT1_ID:?missing}"
: "${SP1_CLIENT_SECRET:?missing}"
: "${GITHUB_PAT:?missing}"
: "${GITHUB_USER:?missing}"

# ==== CONFIG GITHUB (simple) ====
REPO_NAME="Azure-Policies"
BRANCH="Policies_Migration"
CLONE_DIR="${WORKSPACE}/${REPO_NAME}"
POLICIES_DIR="${CLONE_DIR}/policies"
AUTH_URL="https://${GITHUB_USER}:${GITHUB_PAT}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo "[1] Cloning the GitHub repo..."
rm -rf "${CLONE_DIR}"
git clone "${AUTH_URL}" "${CLONE_DIR}" || { echo "[x] Failed to clone repo"; exit 1; }

cd "${CLONE_DIR}"
# checkout la branche demandée (la crée si elle n'existe pas côté remote)
git fetch origin "${BRANCH}" || true
git checkout -B "${BRANCH}" "origin/${BRANCH}" 2>/dev/null || git checkout -b "${BRANCH}"

mkdir -p "${POLICIES_DIR}"

echo "[2] Azure login (service principal)..."
az logout >/dev/null 2>&1 || true
az login --service-principal \
  --username "${AZURE_CLIENT1_ID}" \
  --password="${SP1_CLIENT_SECRET}" \
  --tenant "${AZURE_TENANT1_ID}" >/dev/null

echo "[3] Export custom Policy Definitions..."
az policy definition list --query "[?policyType=='Custom']" -o json > /tmp/policies_all.json

# un fichier par policy (nom basé sur displayName, format compact utile à la réimport)
jq -c '.[]' /tmp/policies_all.json | while read -r def; do
  displayName=$(echo "${def}" | jq -r '.displayName')
  safeName=$(echo "${displayName}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-zA-Z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')

  echo "${def}" \
    | jq '{ name: .name,
            displayName: .displayName,
            description: (.description // empty),
            mode: (.mode // "All"),
            metadata: (.metadata // {}),
            parameters: (.parameters // {}),
            policyRule: .policyRule }' \
    > "${POLICIES_DIR}/${safeName}.json"

  echo "  - ${displayName} -> policies/${safeName}.json"
done

echo "[4] Commit & push..."
git add policies
if git diff --cached --quiet; then
  echo "[i] No changes."
else
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  git -c user.name=jenkins-bot -c user.email=jenkins@local commit -m "chore(policy-export): export @ ${ts} (UTC)"
  git push "${AUTH_URL}" "${BRANCH}"
  echo "[✓] Pushed."
fi

echo "[5] Done ✅"

