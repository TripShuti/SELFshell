// ============================================================
// Workspaces.qml — робочі столи Hyprland на панелі
// ============================================================
import Quickshell.Hyprland
import "../Palette.js" as Palette
import QtQuick


// Віджет робочих столів — номери з кольоровою індикацією
Row {
  id: root

  spacing: 4

  Repeater {
    model: Hyprland.workspaces

    delegate: Item {
      required property HyprlandWorkspace modelData

      // Колір: фокус → акцент, urgent → червоний, активний → світлий, неактивний → muted
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
