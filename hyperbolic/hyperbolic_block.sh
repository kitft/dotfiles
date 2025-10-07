#!/bin/bash

# Script to block incoming traffic on sensitive Ray ports using iptables
# Ray commonly uses ports 6379 (Redis), 8265 (Dashboard), 10001 (GCS), and others

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "Blocking incoming traffic on sensitive Ray ports..."

# Block Ray Dashboard (default: 8265)
iptables -A INPUT -p tcp --dport 8265 -j DROP
echo "✓ Blocked port 8265 (Ray Dashboard)"

# Block Ray GCS Server (default: 6379 for Redis)
iptables -A INPUT -p tcp --dport 6379 -j DROP
echo "✓ Blocked port 6379 (Ray Redis/GCS)"

# Block Ray Client Server (default: 10001)
iptables -A INPUT -p tcp --dport 10001 -j DROP
echo "✓ Blocked port 10001 (Ray GCS Server)"

# Block Ray Object Manager (common ports: 2378-2399)
iptables -A INPUT -p tcp --dport 2378:2399 -j DROP
echo "✓ Blocked ports 2378-2399 (Ray Object Manager)"

# Block Ray Node Manager (common ports: 2470-2500)
iptables -A INPUT -p tcp --dport 2470:2500 -j DROP
echo "✓ Blocked ports 2470-2500 (Ray Node Manager)"

# Block Ray Worker ports (common range: 10002-10999)
iptables -A INPUT -p tcp --dport 10002:10999 -j DROP
echo "✓ Blocked ports 10002-10999 (Ray Worker ports)"

echo ""
echo "All Ray ports blocked successfully!"
echo "To remove these rules, run: iptables -F INPUT"
echo "To persist rules across reboots, run: iptables-save > /etc/iptables/rules.v4"