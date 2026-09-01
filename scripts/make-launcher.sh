#!/usr/bin/env bash
# Build "Mythic Prehistory Server.app" -- a double-clickable Dock launcher that
# starts the server, waits for it to actually be READY, and tells you when you
# can connect. Running it again while the server is up offers to stop it.
#
#   scripts/make-launcher.sh
#
# Rebuild any time; it overwrites the app in place.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Mythic Prehistory Server"
APP="/Applications/${APP_NAME}.app"

echo "==> building ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

# --- Info.plist ---------------------------------------------------------------
cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>dev.aria.mythic-prehistory.launcher</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>launcher</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <!-- No Dock bounce/menu bar takeover: it is a one-shot action, not an app. -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# --- launcher script ----------------------------------------------------------
cat > "${APP}/Contents/MacOS/launcher" <<LAUNCHER
#!/usr/bin/env bash
# GUI apps do not inherit a login shell PATH, so flyctl must be findable here.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="${REPO_DIR}"
HOST="aria-mythic-prehistory.fly.dev"

notify() {
  /usr/bin/osascript -e "display notification \\"\$2\\" with title \\"Mythic Prehistory\\" subtitle \\"\$1\\"" >/dev/null 2>&1 || true
}
dialog() {
  /usr/bin/osascript -e "display dialog \\"\$1\\" with title \\"Mythic Prehistory Server\\" buttons \$2 default button \$3 with icon note" 2>/dev/null
}

cd "\$REPO" || { dialog "Could not find the server repo at:\\n\$REPO" "{\\"OK\\"}" "\\"OK\\""; exit 1; }

STATE_JSON="\$(./mpctl status --json 2>/dev/null)"
MSTATE="\$(printf '%s' "\$STATE_JSON" | jq -r '.machine_state // "unknown"' 2>/dev/null)"
READY="\$(printf '%s' "\$STATE_JSON" | jq -r '.ready // false' 2>/dev/null)"
PLAYERS="\$(printf '%s' "\$STATE_JSON" | jq -r '.players // "?"' 2>/dev/null)"

# --- already up: offer status / stop ---
if [ "\$MSTATE" = "started" ] && [ "\$READY" = "true" ]; then
  CHOICE="\$(dialog "The server is already running and ready.\\n\\nConnect to:  \$HOST\\nPlayers online: \$PLAYERS" "{\\"Stop Server\\", \\"OK\\"}" "\\"OK\\"")"
  case "\$CHOICE" in
    *"Stop Server"*)
      notify "Stopping" "Saving world and taking a backup..."
      ./mpctl stop >/dev/null 2>&1
      notify "Stopped" "World saved and backed up."
      ;;
  esac
  exit 0
fi

# --- starting up ---
if [ "\$MSTATE" = "started" ]; then
  notify "Already booting" "Waiting for the server to finish loading..."
else
  notify "Starting" "Booting the server. This takes about 90 seconds."
fi

if ./mpctl start >/tmp/dc-launcher.log 2>&1; then
  notify "Ready" "Connect to \$HOST"
  dialog "Server is READY.\\n\\nConnect to:  \$HOST\\n\\nIt shuts down on its own 20 minutes after everyone leaves." "{\\"OK\\"}" "\\"OK\\"" >/dev/null
else
  dialog "The server did not come up.\\n\\nLast lines of the log:\\n\$(tail -6 /tmp/dc-launcher.log 2>/dev/null | tr -d '\\"')" "{\\"OK\\"}" "\\"OK\\"" >/dev/null
fi
LAUNCHER

chmod +x "${APP}/Contents/MacOS/launcher"

# --- icon ---------------------------------------------------------------------
# Generated locally rather than shipping any Minecraft/pack artwork.
ICONSET="$(mktemp -d)/icon.iconset"
mkdir -p "${ICONSET}"
python3 - "${ICONSET}" <<'PY'
import sys, os
from PIL import Image, ImageDraw

out = sys.argv[1]

def render(size):
    scale = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # rounded dark slab
    r = int(200 * scale)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=(24, 26, 24, 255))

    # subtle inner border
    d.rounded_rectangle([int(12*scale), int(12*scale), size-1-int(12*scale), size-1-int(12*scale)],
                        radius=int(190*scale), outline=(70, 90, 68, 255), width=max(1, int(8*scale)))

    # a blocky "pickaxe-ish" glyph built from voxel squares, biohazard-green
    cell = 96 * scale
    ox, oy = size/2 - cell*2.5, size/2 - cell*2.5
    green = (124, 179, 66, 255)
    dim   = (86, 125, 46, 255)
    grid = [
        "..###",
        ".##..",
        "###..",
        ".#.#.",
        "....#",
    ]
    for row, line in enumerate(grid):
        for col, ch in enumerate(line):
            if ch != "#":
                continue
            x0 = ox + col*cell
            y0 = oy + row*cell
            d.rectangle([x0, y0, x0+cell*0.88, y0+cell*0.88],
                        fill=green if (row+col) % 2 == 0 else dim)
    return img

for s in (16, 32, 64, 128, 256, 512, 1024):
    render(s).save(os.path.join(out, f"icon_{s}x{s}.png"))
    if s <= 512:
        render(s*2).save(os.path.join(out, f"icon_{s}x{s}@2x.png"))
print("icon frames rendered")
PY

if iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/icon.icns" 2>/dev/null; then
  echo "    icon built"
else
  echo "    WARN: iconutil failed; app will use the generic icon"
fi

# Make Finder/Dock pick up the new icon rather than a cached generic one.
touch "${APP}"
/usr/bin/killall Dock 2>/dev/null || true

echo "==> done: ${APP}"
echo "    Open it once from /Applications, then right-click its Dock icon"
echo "    -> Options -> Keep in Dock."
