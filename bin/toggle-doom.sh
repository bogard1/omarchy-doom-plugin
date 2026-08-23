#!/usr/bin/env bash
# Hides or reveals the running game window via a Hyprland special
# ("scratchpad") workspace -- confirmed via manual testing: moving a window
# into a special workspace that isn't active anywhere shows it as an
# overlay immediately, so hiding needs both the move AND a toggle_special
# right after; showing again is just the toggle_special on its own (the
# window stays parked on that special workspace between toggles).
#
# The hide step targets the game window explicitly by class, via
# `hl.get_windows({ class = ... })` passed as the `window` field on the
# move dispatcher -- NOT "whatever currently has focus". That assumption
# broke in testing: clicking the bar icon doesn't itself steal focus, but
# by the time a player reaches for it to pause, whatever they looked at
# last (a terminal, a browser) is the active window, not the game -- and
# without this, that's the window that gets moved into hiding instead.
set -uo pipefail

action=$1 # "hide" or "show"
binary=$2

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/io.github.bogard1.doom"
log_file="$log_dir/toggle.log"
mkdir -p "$log_dir"

run_eval() {
  echo "[$(date -Iseconds)] $*" >> "$log_file"
  hyprctl eval "$*" >> "$log_file" 2>&1
}

if [[ $action == hide ]]; then
  run_eval "local w = hl.get_windows({ class = '${binary}' }); if w[1] then hl.dispatch(hl.dsp.window.move({ workspace = 'special:doom', window = w[1] })) else error('no window matched class ${binary}') end"
fi
run_eval "hl.dispatch(hl.dsp.workspace.toggle_special('doom'))"
