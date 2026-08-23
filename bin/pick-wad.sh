#!/usr/bin/env bash
# Prompts for a WAD file with a native file dialog and prints the chosen
# path on stdout. Prints nothing and exits non-zero if the user cancels.
set -euo pipefail

exec zenity --file-selection \
  --title="Select a DOOM WAD file" \
  --file-filter="WAD files | *.wad *.WAD" \
  --file-filter="All files | *"
