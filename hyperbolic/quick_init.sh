#!/bin/bash

# Quick initialization script for Hyperbolic nodes
# This is the one-liner you'll run: curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/quick_init.sh | bash -s -- [head|worker] [storage-vip]

curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/hyperbolic_setup.sh -o /tmp/hyperbolic_setup.sh
chmod +x /tmp/hyperbolic_setup.sh
/tmp/hyperbolic_setup.sh "$@"
