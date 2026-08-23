import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Bar icon for the Doom plugin. Left click opens/closes Panel.qml (the
// WAD-pick -> play flow) while no game is running; once one is, left
// click instead pauses+hides it / resumes+shows it (see Panel.qml's
// toggleGameVisibility()), so the panel itself -- and its Quit/Change WAD
// buttons -- stay reachable via right click instead.
BarWidget {
  id: root
  moduleName: "io.github.bogard1.doom"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool gameRunning: panelLoader.item ? panelLoader.item.gameRunning === true : false
  readonly property bool gameHidden: panelLoader.item ? panelLoader.item.gameHidden === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.bogard1.doom"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.gameHidden ? "⏸" : "☠"
    labelVisible: true
    hasVisualContent: true
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      var panel = panelLoader.item
      if (b === Qt.RightButton) { root.togglePanel(); return }
      if (panel && panel.gameRunning) panel.toggleGameVisibility()
      else root.togglePanel()
    }
  }
}
