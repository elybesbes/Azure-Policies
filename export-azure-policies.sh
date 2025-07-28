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
  name=$(echo "$policy" | jq -r '.name')
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
