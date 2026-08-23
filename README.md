# Doom — an Omarchy bar plugin

Play Doom straight from the Omarchy bar: click the skull icon, pick a WAD,
and go. There's no bundled WAD (id Software's IWADs are commercial — bring
your own), so the panel always asks for one first.

## What it does

- Adds a bar-widget icon (`☠`) that opens a small floating panel.
- The panel walks through: is `chocolate-doom` installed → do you have a
  WAD selected → play.
- **Play** launches `chocolate-doom` as a plain, independent, floating
  window (not fullscreen, not tiled — see [Design notes](#design-notes)
  below) and closes the panel so the game gets real keyboard focus.
- Reopen the panel any time to **Quit** the running game or **Change WAD**.

## Requirements

- [`chocolate-doom`](https://aur.archlinux.org/packages/chocolate-doom) —
  AUR-only on Arch (`yay -S chocolate-doom` / `paru -S chocolate-doom`).
  The panel detects if it's missing and offers a one-click terminal with
  that command pre-filled; it never runs an installer on your behalf
  silently. (`doomretro`, in the official `extra` repo, was tried first
  since it needs no AUR helper, but it doesn't reliably exit on `SIGTERM`
  once its window is mapped and needs its own config file patched to avoid
  launching fullscreen — chocolate-doom does neither: a plain `-window`
  flag forces windowed mode and it quits cleanly on `SIGTERM`, both
  confirmed in testing.)
- `zenity` for the WAD file picker (ships by default on most Omarchy
  installs).
- A WAD file you legally own — shareware `doom1.wad`, a retail `DOOM.WAD`/
  `DOOM2.WAD`, or any PWAD you want to load as the IWAD.

## Installing

```bash
omarchy plugin add https://github.com/bogard1/omarchy-doom-plugin.git --enable
```

Or by hand:

```bash
git clone https://github.com/bogard1/omarchy-doom-plugin.git \
  ~/.config/omarchy/plugins/io.github.bogard1.doom
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.bogard1.doom
```

## Design notes

This intentionally does the minimum: launch the game and get out of its
way, rather than managing its window. Two earlier, more ambitious designs
were tried and dropped during testing:

**Pixel-aligning the game into the panel's box.** Wayland/Hyprland don't
support compositing a live *texture* of another process's window into a
QML item while also forwarding mouse/keyboard input to it — the capture
protocols (`wlr-screencopy`, `hyprland-toplevel-export-v1`) are read-only,
and Wayland's virtual-input protocols always target whatever surface
currently holds compositor focus. The fallback — running the game as a
real window and using Hyprland's `windowrulev2` + `movewindowpixel` /
`resizewindowpixel` / `focuswindow` dispatchers to snap it onto the
panel's box — is the standard approach and works on most current
Hyprland installs, but not on this project's dev machine: it runs
Hyprland 0.56's Lua-config branch, which replaced the classic
string-based dispatcher protocol with a structured Lua API
(`hl.dsp.window.*`). Neither `hyprctl dispatch <request>` nor Quickshell's
`Hyprland.dispatch()` QML binding (which sends that same legacy string)
work against it — confirmed by writing directly to Hyprland's IPC socket
and getting back `hl.dispatch: expected a dispatcher`. Exact positioning
was dropped, but plain floating (see `bin/float-doom.sh`) was worth
salvaging on its own: `hyprctl eval "hl.dispatch(hl.dsp.window.float({
action = 'toggle' }))"` is that branch's working equivalent of
`hyprctl dispatch setfloating` — the difference between calling a
dispatcher (`hl.dispatch(hl.dsp.window.float(...))`) and merely
constructing one to bind to a key (`hl.dsp.window.float(...)` alone, the
form every example in Omarchy's own bindings uses) cost some time to
find. `float-doom.sh` waits for the game to actually be the focused
window before calling it, then runs once, detached, right after launch.
On classic (non-Lua) Hyprland the `hyprctl eval` call just fails
harmlessly and the window stays tiled — no worse off than not having this
script at all. No address-targeted absolute positioning shows up anywhere
in Omarchy's `hl.dsp.window.*` examples (`move`/`resize` there take
workspace/relative-delta arguments, not screen coordinates), so exact
pixel alignment on this Hyprland branch remains unsolved.

**Auto-pausing the game when the panel loses focus.** Tried via `SIGSTOP`
on blur / `SIGCONT` on refocus, using Hyprland's toplevel-tracking API to
tell "focus moved to the game we launched" (fine) apart from "focus moved
to something else" (pause). In testing this fought with the game window
for keyboard focus — chocolate-doom accepted no keyboard input at all
while the popup stayed open beside it, and once it did take focus (e.g.
via a mouse click into it), the popup's own click-outside dismissal or a
race in the focus-tracking logic would immediately `SIGSTOP` the game
that had just started, or leave it receiving no input at all. None of the
fixes attempted (suppressing the popup's dismissal while a game is
running, gating the focus watcher on a confirmed window match) resolved
it reliably enough to ship.

If you want to pick either of these back up — e.g. once Quickshell grows
Lua-dispatch support for Hyprland 0.56+, or with more time to work out the
focus-ownership fight — the approach above is the place to start from.

## Files

| File               | Purpose                                             |
|--------------------|------------------------------------------------------|
| `manifest.json`    | Plugin manifest (`bar-widget` kind)                  |
| `BarWidget.qml`    | Bar icon, opens/closes the panel                     |
| `Panel.qml`        | State machine: install check → pick WAD → play       |
| `bin/pick-wad.sh`  | `zenity --file-selection` wrapper for choosing a WAD |
| `bin/float-doom.sh` | Floats the game window post-launch via Hyprland's Lua dispatch API |

## License

MIT — see [LICENSE](LICENSE).
