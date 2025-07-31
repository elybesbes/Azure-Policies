#!/bin/bash

Github_User="elybesbes"
Github_Token="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"
Repo_Name="Azure-Policies"
Repo_URL="https://${Github_User}:${Github_Token}@github.com/${Github_User}/${Repo_Name}.git"
Clone_DIR="$Repo_Name"
Policies_DIR="${Clone_DIR}/policies"

echo "Cloning the GitHub repo..."
rm -rf "$Clone_DIR"
git clone "$Repo_URL" "$Clone_DIR" || { echo "Failed to clone repo"; exit 1; }

mkdir -p "$Policies_DIR"

echo "Fetching all custom Azure Policy definitions..."
az policy definition list --query "[?policyType=='Custom']" -o json > all_custom_policies.json

echo "Splitting policies into individual files..."
jq -c '.[]' all_custom_policies.json | while read -r policy; do
  name=$(echo "$policy" | jq -r '.displayName' | sed 's/[^a-zA-Z0-9_-]/_/g')
  echo "$policy" | jq '.' > "${Policies_DIR}/${name}.json"
done

rm all_custom_policies.json

echo "Configuring Git and pushing to GitHub..."
cd "$Clone_DIR"
git config user.email "elyes@azure.local"
git config user.name "elybesbes"
git add policies/
git commit -m "Export all custom Azure Policies from Cloud Shell"
git push origin main

echo "All done! Check your repo: https://github.com/${Github_User}/${Repo_Name}/tree/main/policies"
