// ============================================================
// WorkspacesWidget.qml — робочі столи Hyprland на панелі
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../core"
import QtQuick

// Віджет робочих столів: номер + іконки вікон.
// ЛКМ — активація стола, ПКМ — попап воркспейса (WorkspacesPopup),
// скрол колесом — перемикання між столами.
Item {
  id: root

  required property QtObject window

  // ПКМ на столі: воркспейс + кнопка-якір для попапа
  signal openPopup(var workspace, Item anchor)

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

        readonly property color dotColor: modelData.focused ? window.palette.green
          : (modelData.urgent ? window.palette.red : (modelData.active ? window.palette.light : window.palette.muted))

        readonly property var wnds: modelData.windows ?? []

        // Ширина залежить від кількості вікон (до 3 іконок + overflow)
        width: Math.max(20, 4 + Math.min(wnds.length, 3) * 9 + (wnds.length > 3 ? 9 : 0))
        height: 28

        Column {
          anchors.centerIn: parent
          spacing: 1

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.id
            color: parent.parent.dotColor
            font.family: window.palette.font
            font.pixelSize: 11
            font.bold: modelData.focused
            scale: modelData.focused ? 1.15 : 1.0

            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on scale {
              NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
          }

          // Іконки вікон стола (до 3), переповнення — "+N"
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1
            visible: wnds.length > 0

            Repeater {
              model: Math.min(wnds.length, 3)

              delegate: IconImage {
                required property int index
                width: 8
                height: 8
                source: wnds[index].icon
                opacity: 0.75
              }
            }

            Text {
              visible: wnds.length > 3
              text: "+" + (wnds.length - 3)
              color: window.palette.muted
              font.family: window.palette.font
              font.pixelSize: 7
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) modelData.activate()
            else root.openPopup(modelData, parent)
          }
          onWheel: wheel => {
            Hyprland.dispatch("workspace " + (wheel.angleDelta.y > 0 ? "+1" : "-1"))
          }
        }
      }
    }
  }
}
