// ============================================================
// TrayWidget.qml — віджет системного трею на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../core"

// Віджет системного трею на панелі — іконки додатків
HoverItem {
  id: root

  required property QtObject window

  implicitWidth: trayRow.implicitWidth
  implicitHeight: parent?.height ?? 36

  RowLayout {
    id: trayRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    Repeater {
      model: SystemTray.items
      delegate: Image {
        source: modelData.icon
        sourceSize: Qt.size(16, 16)
        scale: root.hovered ? 1.15 : 1.0

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) modelData.activate()
            else if (mouse.button === Qt.RightButton) modelData.contextMenu()
          }
        }
      }
    }
  }
}