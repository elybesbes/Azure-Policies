#!/bin/bash

# === CONFIGURATION ===
Github_User="elybesbes"
Github_Token="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"
Repo_Name="Azure-Policies"
Repo_URL="https://${Github_User}:${Github_Token}@github.com/${Github_User}/${Repo_Name}.git"
Clone_DIR="$Repo_Name"
Policies_DIR="${Clone_DIR}/policies"

# === STEP 1: CLONE THE REPO ===
echo "[1] Cloning the GitHub repo..."
rm -rf "$Clone_DIR"
git clone "$Repo_URL" "$Clone_DIR" || { echo "Failed to clone repo"; exit 1; }

cd "$Policies_DIR" || { echo "policies/ folder not found"; exit 1; }

# === STEP 2: IMPORT POLICIES ===
echo "[2] Importing policies into Azure..."

for file in *.json; do
  display_name=$(basename "$file" .json)
  name=$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g')

  echo "Creating policy: $name (display name: $display_name)"

  # Extract only the policyRule block
  jq '.policyRule' "$file" > tmp-policy-rule.json

  # Check if the file is empty or extraction failed
  if [ ! -s tmp-policy-rule.json ]; then
    echo "Skipped $name: policyRule block not found or empty"
    continue
  fi

  # Create the policy definition
  az policy definition create \
    --name "$name" \
    --display-name "$display_name" \
    --rules "tmp-policy-rule.json" \
    --mode All \
    --description "Imported from GitHub by script" || echo "Failed to create $name"

  rm -f tmp-policy-rule.json
done

echo "[3] Done. All policies processed."