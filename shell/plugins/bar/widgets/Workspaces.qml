import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function moveWindowToWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.window.move({ workspace = \"" + id + "\", follow = false })"))
  }

  function cycleWorkspace(delta) {
    if (!root.bar || delta === 0) return
    var target = delta > 0 ? "e-1" : "e+1"
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + target + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      DropArea {
        id: dropTarget
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        implicitWidth: pill.implicitWidth
        implicitHeight: pill.implicitHeight

        onDropped: function(drop) {
          root.moveWindowToWorkspace(modelData)
        }

        WidgetButton {
          id: pill
          anchors.fill: parent
          bar: root.bar
          text: dropTarget.focused ? "\uDB85\uDCFB" : (dropTarget.modelData === 10 ? "0" : String(dropTarget.modelData))
          opacity: dropTarget.containsDrag ? 1 : (dropTarget.occupied || dropTarget.focused ? 1 : 0.5)
          active: dropTarget.containsDrag
          horizontalMargin: 6
          verticalPadding: 6
          fixedWidth: root.vertical ? root.barSize : Style.space(20)
          fixedHeight: root.barSize
          onPressed: function(button) {
            if (button === Qt.RightButton) {
              root.moveWindowToWorkspace(dropTarget.modelData)
            } else {
              root.focusWorkspace(dropTarget.modelData)
            }
          }
          onWheelMoved: function(delta) {
            root.cycleWorkspace(delta)
          }
        }
      }
    }
  }
}
