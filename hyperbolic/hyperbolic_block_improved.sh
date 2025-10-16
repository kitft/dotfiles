#!/bin/bash

# Script to block EXTERNAL traffic on Ray ports while allowing INTERNAL network traffic
# This allows Ray nodes to communicate with each other while blocking internet exposure

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Detect internal network CIDR (customize this for your setup)
INTERNAL_NETWORK=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | grep -v '172.17' | awk '{print $2}' | head -1)
if [ -z "$INTERNAL_NETWORK" ]; then
    echo "❌ Could not detect internal network. Please specify manually."
    exit 1
fi

# Extract network address (e.g., 10.15.28.0/29)
NETWORK_PREFIX=$(echo $INTERNAL_NETWORK | cut -d'.' -f1-3)
INTERNAL_CIDR="${NETWORK_PREFIX}.0/24"

echo "================================================"
echo "Ray Port Security Configuration"
echo "================================================"
echo "Detected internal network: $INTERNAL_NETWORK"
echo "Using CIDR: $INTERNAL_CIDR"
echo ""
read -p "Is this correct? If not, Ctrl+C and edit the script. [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Clear existing INPUT rules to avoid duplicates (WARNING: This removes ALL INPUT rules)
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

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
echo "✓ Allow localhost traffic"

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
echo "✓ Allow established connections"

# Allow SSH (important!)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
echo "✓ Allow SSH (port 22)"

# Allow internal network for ALL Ray ports
iptables -A INPUT -s $INTERNAL_CIDR -j ACCEPT
echo "✓ Allow ALL traffic from internal network: $INTERNAL_CIDR"

# Docker network
iptables -A INPUT -s 172.17.0.0/16 -j ACCEPT
echo "✓ Allow ALL traffic from Docker network: 172.17.0.0/16"

# Now block Ray ports from external sources
echo ""
echo "Blocking external access to Ray ports..."

# Block Ray Dashboard (default: 8265)
iptables -A INPUT -p tcp --dport 8265 -j DROP
echo "✓ Blocked external access to port 8265 (Ray Dashboard)"

# Block Ray GCS Server (default: 6379 for Redis)
iptables -A INPUT -p tcp --dport 6379 -j DROP
echo "✓ Blocked external access to port 6379 (Ray Redis/GCS)"

# Block Ray Client Server (default: 10001)
iptables -A INPUT -p tcp --dport 10001 -j DROP
echo "✓ Blocked external access to port 10001 (Ray GCS Server)"

# Block Ray Object Manager (common ports: 2378-2399)
iptables -A INPUT -p tcp --dport 2378:2399 -j DROP
echo "✓ Blocked external access to ports 2378-2399 (Ray Object Manager)"

# Block Ray Node Manager (common ports: 2470-2500)
iptables -A INPUT -p tcp --dport 2470:2500 -j DROP
echo "✓ Blocked external access to ports 2470-2500 (Ray Node Manager)"

# Block Ray Worker ports (common range: 10002-10999)
iptables -A INPUT -p tcp --dport 10002:10999 -j DROP
echo "✓ Blocked external access to ports 10002-10999 (Ray Worker ports)"

# Block ephemeral ports used by Ray (32768-65535)
# This is the key addition - blocks the dynamically allocated ports
iptables -A INPUT -p tcp --dport 32768:65535 -j DROP
echo "✓ Blocked external access to ports 32768-65535 (Ephemeral ports)"

echo ""
echo "================================================"
echo "✅ Ray ports secured successfully!"
echo "================================================"
echo ""
echo "Summary:"
echo "  - Internal network ($INTERNAL_CIDR): ALLOWED"
echo "  - Docker network (172.17.0.0/16): ALLOWED"
echo "  - External internet: BLOCKED on Ray ports"
echo ""
echo "To view rules: sudo iptables -L INPUT -n -v --line-numbers"
echo "To persist rules across reboots:"
echo "  sudo apt-get install iptables-persistent"
echo "  sudo netfilter-persistent save"
echo ""
echo "⚠️  WARNING: Test Ray cluster connectivity before persisting!"
