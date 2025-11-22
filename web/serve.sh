#!/bin/sh

# Simple script to serve the web interface

cd "$(dirname "$0")"

echo "🌐 Starting Circuit Breaker Token Web Interface..."
echo ""
echo "📋 Make sure:"
echo "   1. Anvil is running (./anvil.sh in another terminal)"
echo "   2. Contracts are deployed (./deployAnvil.sh)"
echo "   3. MetaMask is connected to Anvil (http://127.0.0.1:8545, chainId: 31337)"
echo ""
echo "🚀 Opening http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Try different methods to serve
if command -v python3 > /dev/null 2>&1; then
    python3 -m http.server 8000
elif command -v python > /dev/null 2>&1; then
    python -m SimpleHTTPServer 8000
else
    echo "Error: Python not found. Please install Python or use another web server."
    exit 1
fi
