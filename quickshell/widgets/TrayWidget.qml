// ============================================================
// TrayWidget.qml — віджет системного трею на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../Palette.js" as Palette

// Віджет системного трею на панелі — іконки фонового процесів (Telegram, Slack тощо)
Item {
  id: root

  signal clicked()
  property bool hovered: false

  implicitWidth: trayRow.implicitWidth
  implicitHeight: parent?.height ?? 36

  // Рядок іконок системного трею
  RowLayout {
    id: trayRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    // Кожна іконка — окремий елемент системного трею
    Repeater {
      model: SystemTray.items
      delegate: Image {
        source: modelData.icon
        sourceSize: Qt.size(16, 16)
        scale: root.hovered ? 1.15 : 1.0

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

        // ЛКМ — активувати, ПКМ — контекстне меню
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

  // Збільшення іконок при наведенні
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    propagateComposedEvents: true
  }
}
