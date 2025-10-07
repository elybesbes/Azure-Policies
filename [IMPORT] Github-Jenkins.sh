#!/usr/bin/env bash
set -euo pipefail

# ===== Jenkins params =====
: "${AZURE_TENANT2_ID:?missing}"
: "${AZURE_CLIENT2_ID:?missing}"
: "${SP2_CLIENT_SECRET:?missing}"
: "${GITHUB_USER:?missing}"
: "${GITHUB_PAT:?missing}"

# ===== Repo =====
REPO_NAME="Azure-Policies"
BRANCH="Policies_Migration"
CLONE_DIR="${WORKSPACE}/${REPO_NAME}"
POLICIES_DIR="${CLONE_DIR}/policies"
AUTH_URL="https://${GITHUB_USER}:${GITHUB_PAT}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo "[1] Azure login (service principal)…"
az logout >/dev/null 2>&1 || true
az login --service-principal \
  --username "${AZURE_CLIENT2_ID}" \
  --password "${SP2_CLIENT_SECRET}" \
  --tenant "${AZURE_TENANT2_ID}" >/dev/null
echo "[1] OK ✅"

echo "[2] Clone repo…"
rm -rf "${CLONE_DIR}"
git clone "${AUTH_URL}" "${CLONE_DIR}"
cd "${CLONE_DIR}"
git fetch origin "${BRANCH}" || true
git checkout -B "${BRANCH}" "origin/${BRANCH}" 2>/dev/null || git checkout -b "${BRANCH}"
cd "${POLICIES_DIR}"

echo "[3] Import policies…"
shopt -s nullglob
for file in *.json; do
  # displayName et name (on réutilise .name si présent, sinon slug du displayName)
  display_name="$(jq -r '.displayName // empty' "${file}")"
  [ -n "${display_name}" ] || display_name="$(basename "${file}" .json)"
  name="$(jq -r '.name // empty' "${file}")"
  if [ -z "${name}" ] || [ "${name}" = "null" ]; then
    name="$(echo "${display_name}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')"
  fi

  # rule + parameters (si présents)
  jq '.policyRule' "${file}" > /tmp/policy-rule.json
  jq '.parameters // {}' "${file}" > /tmp/policy-params.json

  echo "  - ${name} (\"${display_name}\")"
  if [ "$(jq 'length' /tmp/policy-params.json)" -gt 0 ]; then
    az policy definition create \
      --name "${name}" \
      --display-name "${display_name}" \
      --rules /tmp/policy-rule.json \
      --params /tmp/policy-params.json \
      --mode All \
      --description "Imported from GitHub by Jenkins" >/dev/null || echo "    warn: create failed"
  else
    az policy definition create \
      --name "${name}" \
      --display-name "${display_name}" \
      --rules /tmp/policy-rule.json \
      --mode All \
      --description "Imported from GitHub by Jenkins" >/dev/null || echo "    warn: create failed"
  fi
done
shopt -u nullglob

echo "[4] Done ✅"
