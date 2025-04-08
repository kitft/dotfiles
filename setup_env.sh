#!/bin/bash
# setup_env.sh

# We should be already in the correct repo 
# Use GitHub CLI to access secrets and create .env file
# (Requires gh CLI to be installed and authenticated)
gh secret list | while read -r line; do
    # Extract just the secret name (first column)
    key=$(echo "$line" | awk '{print $1}')
    # Get the secret value
    value=$(gh secret get "$key")
    # Append to .env
    echo "$key=$value" >> .env
done
