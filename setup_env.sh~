#!/bin/bash

# Create a temporary directory for cloning
temp_dir=$(mktemp -d)

echo "Cloning kitft/secrets repository..."
git clone https://github.com/kitft/secrets.git "$temp_dir" || {
    echo "Failed to clone repository. Please check if it exists and you have access."
    rm -rf "$temp_dir"
    exit 1
}

# Check if .env exists in the cloned repo
if [ ! -f "$temp_dir/.env" ]; then
    echo "Error: .env file not found in the cloned repository."
    rm -rf "$temp_dir"
    exit 1
fi

echo "Found .env file in the cloned repository."

# Create .env file if it doesn't exist locally
if [ ! -f "./.env" ]; then
    touch ./.env
    echo "Created new local .env file."
fi

echo "" >> ./.env  # Add a newline for cleaner separation
echo "# Added from kitft/secrets" >> ./.env
cat "$temp_dir/.env" >> ./.env

echo "Successfully appended secrets to your local .env file."

# Clean up the temporary directory
rm -rf "$temp_dir"
echo "Cleanup complete."
