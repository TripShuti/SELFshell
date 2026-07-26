// ============================================================
// Workspaces.qml — робочі столи Hyprland на панелі
// ============================================================
import Quickshell.Hyprland
import "../Palette.js" as Palette
import QtQuick

Item {
  id: root

  signal clicked()
  property bool hovered: false

  implicitHeight: parent?.height ?? 36
  implicitWidth: row.implicitWidth

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Repeater {
      model: Hyprland.workspaces

      delegate: Item {
        required property HyprlandWorkspace modelData

        readonly property color dotColor: modelData.focused ? Palette.green
          : (modelData.urgent ? Palette.red : (modelData.active ? Palette.light : Palette.muted))

        width: 20
        height: 28

        Text {
          anchors.centerIn: parent
          text: modelData.id
          color: parent.dotColor
          font.family: Palette.font
          font.pixelSize: 12
          font.bold: modelData.focused
          scale: modelData.focused ? 1.15 : 1.0

          Behavior on color { ColorAnimation { duration: 220 } }
          Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: modelData.activate()
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    propagateComposedEvents: true
  }
}
