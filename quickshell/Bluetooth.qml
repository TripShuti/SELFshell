// ============================================================
// Bluetooth.qml — іконка Bluetooth на панелі
// ============================================================
import Quickshell.Bluetooth
import "Palette.js" as Palette
import QtQuick

// Іконка Bluetooth на панелі — показує стан адаптера
Item {
  id: root

  signal clicked()

  implicitWidth: 15
  implicitHeight: 10

  property BluetoothAdapter adapter: Bluetooth.defaultAdapter
  property bool btEnabled: adapter?.enabled ?? false
  property bool hovered: false

  // Іконка Bluetooth — синя якщо увімкнено, сіра якщо вимкнено
  Text {
    anchors.centerIn: parent
    text: ""
    color: root.btEnabled ? Palette.blue : Palette.muted
    font.family: Palette.font; font.pixelSize: 16
    scale: root.hovered ? 1.22 : 1.0

    Behavior on color { ColorAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
