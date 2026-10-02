#!/bin/bash
# Make fresh pet chats about today's Korean search trends with Claude, for the pets to use.
# Writes ~/.clawd-pet/ai-<time>.txt (A:/B: lines, blank line between chats).
DIR="$HOME/.clawd-pet"
LOCK="$DIR/ai-running"
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# LaunchAgents get a bare PATH; look where Claude Code usually lives
CLAUDE=$(command -v claude || ls "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" /opt/homebrew/bin/claude /usr/local/bin/claude 2>/dev/null | head -1)
[ -n "$CLAUDE" ] || exit 1

topics=$(curl -fsSL https://storage.googleapis.com/benyco-trends-kr/data/search-000000000000.json | python3 -c '
import json, random, sys
day = max(json.load(sys.stdin)["days"], key=lambda d: d["date"])
top = day["terms"][:20]
for t in random.sample(top, min(8, len(top))):
    print("- %s: %s / %s" % (t["term"], t.get("who", ""), t.get("why", "")))
') || exit 1

# hooks off so this run doesn't trigger the "done" announcement
echo '{"disableAllHooks": true}' > "$DIR/ai-settings.json"
# topics are outside text: no tools or MCP servers, so it can only write text
out=$(cd "$DIR" && { cat "$DIR/ai-prompt.txt"; echo "$topics"; } |
  "$CLAUDE" -p --model haiku --max-turns 1 --no-session-persistence --settings "$DIR/ai-settings.json" \
    --tools "" --strict-mcp-config) || exit 1

# keep only A:/B: lines and blank lines; drop emoji the bubble can't draw
chat=$(printf '%s\n' "$out" | grep -E '^[[:space:]]*[AB][[:space:]]*:|^[[:space:]]*$' |
  perl -CSD -pe 's/[\x{2600}-\x{27BF}\x{FE0F}\x{1F000}-\x{1FFFF}]//g')
if printf '%s' "$chat" | grep -qE '[AB][[:space:]]*:'; then
  f="$DIR/ai-$(date +%s).txt"
  printf '%s\n' "$chat" > "$f.tmp" && mv "$f.tmp" "$f"
fi
