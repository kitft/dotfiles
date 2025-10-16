#!/bin/bash

# Script to block ALL external traffic on Ray ports - localhost only
# This is the most secure option - blocks everything except localhost

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "================================================"
echo "Ray Port Security - LOCALHOST ONLY MODE"
echo "================================================"
echo "This will block ALL Ray ports from external access."
echo "Only localhost connections will be allowed."
echo ""
echo "⚠️  WARNING: This will prevent Ray multi-node clusters!"
echo "   Use this ONLY for single-node setups or testing."
echo ""

read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Clear existing INPUT rules to avoid duplicates
read -p "⚠️  This will FLUSH all existing INPUT iptables rules. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

iptables -F INPUT
echo "✓ Flushed existing INPUT rules"

# Default policy: ACCEPT (we'll add specific DROP rules)
iptables -P INPUT ACCEPT

echo ""
echo "Adding firewall rules..."
echo ""

# Allow loopback (localhost)
iptables -A INPUT -i lo -j ACCEPT
echo "✓ Allow localhost traffic"

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
echo "✓ Allow established connections"

# Allow SSH (important!)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
echo "✓ Allow SSH (port 22)"

# Now block ALL Ray ports from external sources
echo ""
echo "Blocking ALL external access to Ray ports..."

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

# Block ephemeral ports used by Ray (32768-65535)
iptables -A INPUT -p tcp --dport 32768:65535 -j DROP
echo "✓ Blocked ports 32768-65535 (Ephemeral ports)"

# Block additional common Ray port ranges
iptables -A INPUT -p tcp --dport 20000:30000 -j DROP
echo "✓ Blocked ports 20000-30000 (Additional Ray ports)"

echo ""
echo "================================================"
echo "✅ Ray ports locked down - LOCALHOST ONLY!"
echo "================================================"
echo ""
echo "Summary:"
echo "  - Localhost (127.0.0.1): ALLOWED"
echo "  - SSH (port 22): ALLOWED"
echo "  - Established connections: ALLOWED"
echo "  - ALL other Ray ports: BLOCKED"
echo ""
echo "To view rules: sudo iptables -L INPUT -n -v --line-numbers"
echo "To persist rules across reboots:"
echo "  sudo apt-get install iptables-persistent"
echo "  sudo netfilter-persistent save"
echo ""
echo "⚠️  Run the port checker again to verify!"
