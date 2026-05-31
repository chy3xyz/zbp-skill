#!/bin/bash
# Install zbp-skill (Zig Best Practice) into Claude Code.
# One command: curl -fsSL https://raw.githubusercontent.com/chy3xyz/zbp-skill/main/install.sh | bash
set -e

REPO="https://github.com/chy3xyz/zbp-skill.git"
PLUGIN_DIR="${HOME}/.claude/plugins/cache/zbp-skill"
MARKETPLACE_DIR="${HOME}/.claude/plugins/marketplaces/zbp-skill"
SETTINGS="${HOME}/.claude/settings.json"

echo "=== zbp-skill installer ==="

# Clone marketplace if missing
if [ ! -d "$MARKETPLACE_DIR" ]; then
    echo "Cloning marketplace..."
    git clone --depth 1 "$REPO" "$MARKETPLACE_DIR"
else
    echo "Marketplace exists, updating..."
    git -C "$MARKETPLACE_DIR" pull --ff-only
fi

# Copy plugin to cache
echo "Installing plugin to cache..."
rm -rf "$PLUGIN_DIR"
cp -r "$MARKETPLACE_DIR/plugins/zbp-skill" "$PLUGIN_DIR"

# Add marketplace to settings.json if not present
if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
    with open('$SETTINGS') as f:
        s = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    s = {}

s.setdefault('extraKnownMarketplaces', {})
if 'zbp-skill' not in s['extraKnownMarketplaces']:
    s['extraKnownMarketplaces']['zbp-skill'] = {
        'source': {'source': 'github', 'repo': 'chy3xyz/zbp-skill'}
    }

s.setdefault('enabledPlugins', {})
s['enabledPlugins']['zbp-skill@zbp-skill'] = True

with open('$SETTINGS', 'w') as f:
    json.dump(s, f, indent=2)
"
fi

echo ""
echo "Done. Restart Claude Code or run /reload-plugins to activate."
echo "Verify: the 'zbp' skill auto-loads when editing .zig files."
