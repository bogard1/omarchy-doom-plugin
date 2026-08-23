#!/usr/bin/env bash
# Floats the just-launched game window instead of leaving it tiled, and
# sizes it to the resolution chosen in the panel.
#
# Hyprland's classic `hyprctl dispatch setfloating`/`hyprctl keyword
# windowrulev2 float,...` don't work on Hyprland 0.56's Lua-config branch
# (confirmed: both return "hl.dispatch: expected a dispatcher") -- this is
# that branch's equivalent: `hl.dispatch(hl.dsp.window.<action>(...))`
# executes a dispatcher immediately, versus `hl.bind(key, hl.dsp...)` which
# only binds it to a key. Absolute resize is `window.resize({ x, y })`
# (width/height, despite the names) with no `relative` flag -- add
# `relative = true` and those become deltas instead, which is the only form
# shown anywhere in Omarchy's own bindings and isn't what we want here.
# `window.center()` (classic Hyprland's `centerwindow`) takes no arguments
# and re-centers on whatever size the window is at that point, so it runs
# after the resize rather than before.
#
# Runs detached right after launch; waits for the game to actually become
# the focused window first; on classic (non-Lua) Hyprland the `hyprctl
# eval` calls below just fail harmlessly (game stays tiled at whatever size
# it picked itself) -- no worse off than before this script existed.
set -euo pipefail

binary=$1
resolution=$2 # WIDTHxHEIGHT
width=${resolution%x*}
height=${resolution#*x}

for _ in $(seq 1 20); do
  if hyprctl activewindow 2>/dev/null | grep -q "class: ${binary}$"; then
    hyprctl eval "hl.dispatch(hl.dsp.window.float({ action = 'toggle' }))" >/dev/null 2>&1 || true
    hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = ${width}, y = ${height} }))" >/dev/null 2>&1 || true
    hyprctl eval "hl.dispatch(hl.dsp.window.center())" >/dev/null 2>&1 || true
    exit 0
  fi
  sleep 0.3
done
