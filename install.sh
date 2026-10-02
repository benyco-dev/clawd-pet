#!/bin/bash
# Build the desktop pets, start them now and at every login, and hook them to Claude Code.
# Usage: bash install.sh                (clawd + white + black)
#        bash install.sh white black    (pick pets)
set -e
cd "$(dirname "$0")"
DIR="$HOME/.clawd-pet"
PETS="${*:-clawd white black}"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools가 필요해요. 설치 창에서 '설치'를 누르고, 끝나면 이 스크립트를 다시 실행하세요."
  xcode-select --install
  exit 1
fi

mkdir -p "$DIR"
[ -f "$DIR/lines.txt" ] || cp lines.txt "$DIR/lines.txt"  # keep your edited lines on reinstall
[ -f "$DIR/ai-prompt.txt" ] || cp ai-prompt.txt "$DIR/ai-prompt.txt"
cp ai.sh "$DIR/ai.sh" && chmod +x "$DIR/ai.sh"  # AI chats about today's trends (uses Claude Code)
echo "빌드 중... (1분 정도)"
swiftc -O -swift-version 5 ClawdPet.swift -o "$DIR/clawd-pet"

# Start at login (and now)
PLIST="$HOME/Library/LaunchAgents/com.clawd.pet.plist"
mkdir -p "$HOME/Library/LaunchAgents"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  echo '<plist version="1.0"><dict>'
  echo '  <key>Label</key><string>com.clawd.pet</string>'
  echo '  <key>ProgramArguments</key><array>'
  echo "    <string>$DIR/clawd-pet</string>"
  for p in $PETS; do echo "    <string>$p</string>"; done
  echo '  </array>'
  echo '  <key>RunAtLoad</key><true/>'
  echo '</dict></plist>'
} > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"

# Claude Code Stop hook: a random pet says "done" when Claude finishes
python3 - <<'EOF'
import json, os
p = os.path.expanduser('~/.claude/settings.json')
s = json.load(open(p)) if os.path.exists(p) else {}
cmd = 'mkdir -p ~/.clawd-pet && touch ~/.clawd-pet/done'
stop = s.setdefault('hooks', {}).setdefault('Stop', [])
if not any(h.get('command') == cmd for e in stop for h in e.get('hooks', [])):
    stop.append({'hooks': [{'type': 'command', 'command': cmd, 'async': True}]})
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p + '.tmp', 'w') as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
    os.replace(p + '.tmp', p)
    print('Claude Code 완료 알림 훅을 추가했어요.')
EOF

# Desktop buttons: double-click to start/stop all pets
for pair in "start-pets.command:펫 모두 켜기" "stop-pets.command:펫 모두 끄기"; do
  dst="$HOME/Desktop/${pair#*:}.command"
  cp "${pair%%:*}" "$dst"
  chmod +x "$dst"
  xattr -c "$dst" 2>/dev/null || true  # drop the download quarantine flag
done

echo "완료! 펫이 Dock 위에 나타나요. (펫 우클릭 = 끄기, 바탕화면에 '펫 모두 켜기/끄기' 추가됨)"
