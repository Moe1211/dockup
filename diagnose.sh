#!/bin/bash
# DockUp Diagnostic Script
# Run this on your VPS to diagnose issues

set -e

echo "=== DockUp Diagnostic Report ==="
echo ""

echo "1. Service Status:"
systemctl status dockup --no-pager -l || true
echo ""

echo "2. Recent Logs:"
journalctl -u dockup -n 50 --no-pager || true
echo ""

echo "3. Agent Binary:"
if [ -f /usr/local/bin/dockup-agent ]; then
    ls -lh /usr/local/bin/dockup-agent
    file /usr/local/bin/dockup-agent
    /usr/local/bin/dockup-agent -h 2>&1 || echo "Binary exists but may have issues"
else
    echo "❌ Binary not found at /usr/local/bin/dockup-agent"
fi
echo ""

echo "4. Registry File:"
if [ -f /etc/dockup/registry.json ]; then
    echo "File exists:"
    ls -lh /etc/dockup/registry.json
    echo ""
    echo "Content:"
    cat /etc/dockup/registry.json
    echo ""
    echo "JSON validity:"
    jq . /etc/dockup/registry.json > /dev/null && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
else
    echo "❌ Registry file not found"
fi
echo ""

echo "5. Port 8080:"
if command -v netstat > /dev/null; then
    netstat -tuln | grep 8080 || echo "Port 8080 is free"
elif command -v ss > /dev/null; then
    ss -tuln | grep 8080 || echo "Port 8080 is free"
else
    echo "Cannot check port (netstat/ss not available)"
fi
echo ""

echo "6. Test Binary Execution:"
if [ -f /usr/local/bin/dockup-agent ]; then
    echo "Attempting to run with test config..."
    /usr/local/bin/dockup-agent -port 8080 -config /etc/dockup/registry.json 2>&1 &
    TEST_PID=$!
    sleep 2
    if ps -p $TEST_PID > /dev/null; then
        echo "✅ Binary can start"
        kill $TEST_PID 2>/dev/null || true
    else
        echo "❌ Binary crashes immediately"
        wait $TEST_PID 2>/dev/null || true
    fi
fi
echo ""

echo "=== End of Diagnostic ==="

