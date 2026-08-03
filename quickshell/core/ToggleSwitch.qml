// ============================================================
// core/ToggleSwitch.qml — перемикач (тумблер)
// ============================================================
import QtQuick

// Перемикач з анімованим повзунком. Використовується для
// Wi-Fi/Bluetooth і подібних вмикачів у попапах.
Item {
  id: root

  property bool checked: false
  property QtObject palette: null
  signal toggled(bool value)

  // Розміри та колір увімкненого стану — різні копії в попапах
  // використовували трохи різні значення (36x22/32x18, accent/widgetFg)
  property color checkedColor: root.palette.accent
  property int trackWidth: 36
  property int trackHeight: 22
  property int knobSize: 18

  implicitWidth: root.trackWidth
  implicitHeight: root.trackHeight

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: root.trackHeight / 2
    color: root.checked ? root.checkedColor : root.palette.bg2
    Behavior on color { ColorAnimation { duration: 150 } }
    border.width: bgArea.containsMouse ? 1 : 0
    border.color: root.palette.hoverOverlay
    Behavior on border.width { NumberAnimation { duration: 120 } }
  }

  Rectangle {
    x: root.checked ? parent.width - width - 2 : 2
    width: root.knobSize; height: root.knobSize; radius: root.knobSize / 2
    color: root.checked ? root.palette.bg1 : root.palette.gray
    anchors.verticalCenter: parent.verticalCenter
    Behavior on x { NumberAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  MouseArea {
    id: bgArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
