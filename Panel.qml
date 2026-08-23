import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Doom panel: pick a WAD, then play. This deliberately does the minimum:
// launch chocolate-doom as a plain, independent window and get out of the
// way. Earlier revisions tried tracking the game's window (via Hyprland's
// toplevel/dispatch APIs) to pixel-align it into this panel and to
// auto-pause it on focus loss -- both had to be dropped. Neither
// `hyprctl dispatch`/Quickshell's `Hyprland.dispatch()` (this Hyprland
// build uses a Lua-based dispatcher API instead — see the plugin README)
// nor keeping this popup alive alongside the game window (which fought it
// for keyboard focus, or double-triggered "click outside" dismissal the
// instant the game took focus) turned out reliable. So: ask for a WAD,
// launch it, hide the popup so the game gets real input focus, done.
Panel {
  id: root
  moduleName: "io.github.bogard1.doom"
  ipcTarget: "io.github.bogard1.doom"
  // BarWidget.qml already registers an IpcHandler on this target; letting
  // the base Panel register a second one on the same target would collide.
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

  property bool doomInstalled: true
  property bool checkedInstalled: false

  property string wadPath: ""
  readonly property string wadName: wadPath.length ? wadPath.split("/").pop() : ""

  property bool gameRunning: false
  property bool gameHidden: false

  property string resolution: "1024x768"
  readonly property var resolutionOptions: ["800x600", "1024x768", "1280x720", "1920x1080"]
  // Mirrors Dropdown.qml's own popup implicitHeight formula -- it doesn't
  // expose that as a property, and this panel needs it to reserve room
  // (see PopupCard.contentHeight below) before the popup actually opens.
  readonly property real dropdownPopupHeight: Style.spacing.popupRowHeight * resolutionOptions.length
    + Math.max(0, resolutionOptions.length - 1) * Style.spacing.labelGap + Style.spacing.xxs

  readonly property int panelWidth: Style.space(260)

  // The Doom source port this plugin drives. chocolate-doom takes a plain
  // `-window` CLI flag to force windowed mode (no config-file surgery
  // needed) and, unlike doomretro, actually exits cleanly on SIGTERM --
  // both confirmed in testing. It's AUR-only on Arch (`yay -S
  // chocolate-doom`), unlike doomretro which is in the official `extra`
  // repo, but the reliability difference is worth the extra install step.
  readonly property string doomBinary: "chocolate-doom"

  function open() {
    root.checkInstalled()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  // ---- Dependency check ---------------------------------------------
  function checkInstalled() {
    checkInstalledProc.running = true
  }

  Process {
    id: checkInstalledProc
    command: ["bash", "-c", "command -v " + root.doomBinary]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.doomInstalled = String(text || "").trim().length > 0
        root.checkedInstalled = true
      }
    }
  }

  function openInstallTerminal() {
    Quickshell.execDetached(["bash", "-c", "xdg-terminal-exec -- yay -S " + root.doomBinary])
  }

  // ---- WAD picking -----------------------------------------------------
  // The zenity dialog steals window focus from our popup the moment it
  // opens. PopupCard's click-outside dismissal (HyprlandFocusGrab) reads
  // that as "user dismissed the panel" and closes it -- so without this
  // flag, picking a WAD looks like it silently does nothing (it actually
  // still finishes in the background and lands in wadPath, just behind a
  // closed panel). Suspending outside-click dismissal for the duration of
  // the picker keeps the panel open through the dialog.
  property bool wadPickerPending: false

  function pickWad() {
    root.wadPickerPending = true
    pickWadProc.running = true
  }

  Process {
    id: pickWadProc
    command: [root.pluginDir + "/bin/pick-wad.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim()
        if (path.length > 0) root.wadPath = path
        root.wadPickerPending = false
      }
    }
  }

  // ---- Launch / quit -----------------------------------------------------
  function launchDoom() {
    if (root.wadPath.length === 0 || root.gameRunning) return
    gameProcess.command = [root.doomBinary, "-iwad", root.wadPath, "-window", "-geometry", root.resolution]
    gameProcess.running = true
    Quickshell.execDetached([root.pluginDir + "/bin/float-doom.sh", root.doomBinary, root.resolution])
    // Get out of the way immediately so the game window is free to take
    // real keyboard focus, rather than competing with this popup for it.
    root.close()
  }

  Process {
    id: gameProcess
    onStarted: root.gameRunning = true
    onExited: function(exitCode, exitStatus) {
      root.gameRunning = false
      root.gameHidden = false
    }
  }

  // ---- Pause + hide / resume + show --------------------------------------
  // Bound to clicking the bar icon while a game is running (see
  // BarWidget.qml) rather than to any automatic focus-loss detection -- an
  // earlier revision tried that and it fought the game for keyboard focus
  // (see README's Design notes). This only ever runs from an explicit
  // click, so there's no race to get wrong.
  function toggleGameVisibility() {
    if (!root.gameRunning) return
    if (root.gameHidden) root.showGame()
    else root.hideGame()
  }

  function hideGame() {
    gameProcess.signal(19) // SIGSTOP
    Quickshell.execDetached([root.pluginDir + "/bin/toggle-doom.sh", "hide", root.doomBinary])
    root.gameHidden = true
  }

  function showGame() {
    gameProcess.signal(18) // SIGCONT
    Quickshell.execDetached([root.pluginDir + "/bin/toggle-doom.sh", "show", root.doomBinary])
    root.gameHidden = false
  }

  function quitGame() {
    if (!root.gameRunning) return
    gameProcess.signal(15) // SIGTERM
    quitForceTimer.restart()
  }

  Timer {
    // Defensive backstop: chocolate-doom exits cleanly on SIGTERM in
    // testing, but a source port swapped in via doomBinary might not.
    id: quitForceTimer
    interval: 1500
    onTriggered: if (root.gameRunning) gameProcess.signal(9) // SIGKILL
  }

  Component.onCompleted: root.checkInstalled()

  // ---- UI ----------------------------------------------------------------
  // qs.Ui.Panel (the base type above) only owns open/close state and IPC --
  // it renders nothing itself. The actual floating window, and registering
  // as the bar's one-popup-at-a-time "active popout", is PopupCard's job
  // (see Ui/PopupCard.qml); every first-party panel nests its content inside
  // one of these rather than drawing directly under the Panel root.
  PopupCard {
    id: card
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    triggerMode: root.wadPickerPending ? "hover" : "click"
    contentWidth: card.fittedContentWidth(root.panelWidth)
    // The card is a real window sized to `content`'s collapsed height --
    // Dropdown's own option list pops up as an overlay, which has nowhere
    // to expand into and gets clipped unless room is reserved up front.
    contentHeight: card.fittedContentHeight(content.implicitHeight + (resolutionDropdown.popupOpen ? root.dropdownPopupHeight : 0))

    Column {
      id: content
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        text: "Doom"
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        visible: !root.checkedInstalled
        text: "Checking for " + root.doomBinary + "…"
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: Style.font.family
      }

      Row {
        spacing: Style.spacing.sm
        visible: root.checkedInstalled && !root.doomInstalled

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.doomBinary + " isn't installed"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
        }
        Button {
          text: "Install"
          onClicked: root.openInstallTerminal()
        }
      }

      Row {
        spacing: Style.spacing.sm
        visible: root.checkedInstalled && root.doomInstalled && root.wadPath.length === 0

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "No WAD selected"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
        }
        Button {
          text: "Select WAD…"
          onClicked: root.pickWad()
        }
      }

      Column {
        width: parent.width
        spacing: Style.spacing.sm
        visible: root.checkedInstalled && root.doomInstalled && root.wadPath.length > 0 && !root.gameRunning

        Text {
          text: root.wadName
          // Explicit, not cosmetic: wadName comes straight from a
          // user-picked file's basename. QML's default Text.AutoText
          // detects and renders markup-shaped content as rich text, so a
          // WAD file named to look like an <img> tag would make this
          // label fetch an attacker-chosen remote resource just by being
          // displayed. Forcing plain text closes that off entirely.
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
        }

        Dropdown {
          id: resolutionDropdown
          label: "Resolution"
          width: parent.width
          value: root.resolution
          options: root.resolutionOptions
          onChanged: function(value) { root.resolution = value }
        }

        Row {
          spacing: Style.spacing.sm

          Button {
            text: "Play"
            onClicked: root.launchDoom()
          }
          Button {
            text: "Change WAD"
            onClicked: root.pickWad()
          }
        }
      }

      Row {
        spacing: Style.spacing.sm
        visible: root.gameRunning

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.gameHidden ? "Doom is paused (hidden)" : "Doom is running"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
        }
        Button {
          text: "Quit"
          onClicked: root.quitGame()
        }
      }
    }
  }
}
