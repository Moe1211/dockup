#!/bin/bash
# Quick script to update domain URLs in install.sh and index.html
# Usage: ./setup-domain.sh your-domain.com

if [ -z "$1" ]; then
    echo "Usage: ./setup-domain.sh your-domain.com"
    echo "Example: ./setup-domain.sh dockup.example.com"
    exit 1
fi

DOMAIN="$1"

echo "Updating domain to: $DOMAIN"

# Update install.sh
if [ -f "install.sh" ]; then
    sed -i.bak "s|https://raw.githubusercontent.com/yourusername/dockup/main|https://$DOMAIN|g" install.sh
    echo "✅ Updated install.sh"
    rm -f install.sh.bak
else
    echo "⚠️  install.sh not found"
fi

# Update index.html
if [ -f "index.html" ]; then
    sed -i.bak "s|https://your-domain.com|https://$DOMAIN|g" index.html
    echo "✅ Updated index.html"
    rm -f index.html.bak
else
    echo "⚠️  index.html not found"
fi

echo ""
echo "✅ Domain configuration complete!"
echo ""
echo "Next steps:"
echo "1. Host these files on $DOMAIN"
echo "2. Test the installer:"
echo "   curl -fsSL https://$DOMAIN/install.sh | bash -s -- setup user@vps-ip"

