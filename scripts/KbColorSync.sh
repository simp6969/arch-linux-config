#!/bin/bash
# /* ---- Acer Keyboard Color Sync from Wallpaper ---- */
# Reads the dominant wallust color and sets the Acer keyboard backlight to match.
# Can be run standalone or hooked into WallustSwww.sh.

# Resolve the real user's home (even under sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  REAL_HOME="$HOME"
fi

STATIC_DEV="/dev/acer-gkbbl-static-0"
MAIN_DEV="/dev/acer-gkbbl-0"
COLORS_FILE="$REAL_HOME/.config/hypr/wallust/wallust-hyprland.conf"

# Which wallust variable to use (color10 = most vibrant dominant color)
COLOR_VAR="color10"

# ── Preflight checks ────────────────────────────────
if [[ ! -e "$STATIC_DEV" ]]; then
  echo "KbColorSync: $STATIC_DEV not found – is the acer-gkbbl kernel module loaded?"
  exit 1
fi

if [[ ! -f "$COLORS_FILE" ]]; then
  echo "KbColorSync: $COLORS_FILE not found – run wallust first."
fi

# ── Extract hex color ───────────────────────────────
hex=$(grep -oP "^\\\$$COLOR_VAR\s*=\s*rgb\(\K[A-Fa-f0-9]{6}" "$COLORS_FILE" | head -n1)

if [[ -z "$hex" ]]; then
  echo "KbColorSync: Could not parse $COLOR_VAR from $COLORS_FILE"
  exit 1
fi

# ── Convert hex → decimal RGB ────────────────────────
r=$(( 16#${hex:0:2} ))
g=$(( 16#${hex:2:2} ))
b=$(( 16#${hex:4:2} ))

echo "KbColorSync: Setting keyboard to $COLOR_VAR = #$hex (R=$r G=$g B=$b)"

# ── Use python for reliable binary writes ────────────
# This mirrors exactly what Linux-NitroSense/utils/keyboard.py does
python3 -c "
STATIC = '$STATIC_DEV'
MAIN   = '$MAIN_DEV'
r, g, b = $r, $g, $b

# Write static color to all 4 zones (same as _set_static_mode)
for zone in range(1, 5):
    payload = [0] * 4
    payload[0] = 1 << (zone - 1)  # zone bitmask
    payload[1] = r
    payload[2] = g
    payload[3] = b
    with open(STATIC, 'wb') as f:
        f.write(bytes(payload))

# Switch to static mode (mode=0) + set brightness
# This takes the keyboard OUT of rainbow/dynamic mode
payload = [0] * 16
payload[0] = 0     # mode 0 = static
payload[2] = 100   # brightness (100 = max, 0 = off)
payload[9] = 1     # apply flag
with open(MAIN, 'wb') as f:
    f.write(bytes(payload))
"

echo "KbColorSync: Done ✓"
