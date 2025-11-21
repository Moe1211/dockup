#!/bin/bash
# Check version consistency across DockUp files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Extract version from dockup script
DOCKUP_VERSION=$(grep -E '^DOCKUP_VERSION=' "$PROJECT_ROOT/dockup" | cut -d'"' -f2 || echo "")

if [ -z "$DOCKUP_VERSION" ]; then
    echo "❌ Could not find DOCKUP_VERSION in dockup script"
    exit 1
fi

echo "✓ Found version in dockup script: $DOCKUP_VERSION"

# Check if version is mentioned in README (optional check)
if grep -q "$DOCKUP_VERSION" "$PROJECT_ROOT/README.md" 2>/dev/null; then
    echo "✓ Version found in README.md"
elif grep -q "v[0-9]" "$PROJECT_ROOT/README.md" 2>/dev/null; then
    echo "⚠️  Version in README.md may be outdated"
fi

# Check if version is mentioned in ROADMAP (optional check)
if grep -q "$DOCKUP_VERSION\|v[0-9]" "$PROJECT_ROOT/ROADMAP.md" 2>/dev/null; then
    echo "✓ Version found in ROADMAP.md"
fi

echo "✅ Version check passed: $DOCKUP_VERSION"
exit 0

