// ============================================================
// ClockWidget.qml — годинник на панелі
// ============================================================
import Quickshell
import "../core"
import QtQuick


// Віджет годинника на панелі — показує поточний час
Item {
  id: root

  required property QtObject window
  signal clicked()
  property bool hovered: false

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color:  window.palette.widgetFg
    font.family: window.palette.font
    font.pixelSize: 14
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    scale: root.hovered ? 1.15 : 1.0

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
