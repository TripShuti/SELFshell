// ============================================================
// ClockWidget.qml — годинник на панелі
// ============================================================
import Quickshell
import "../Palette.js" as Palette
import QtQuick


// Віджет годинника на панелі — показує поточний час
Item {
  id: root

  signal clicked()
  property bool hovered: false

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // Тінь тексту (світіння при наведенні)
  Text {
    anchors.centerIn: label
    text: label.text
    color: Palette.widgetFg
    font: label.font
    opacity: root.hovered ? 0.35 : 0
    scale: 1.08
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color:  Palette.widgetFg
    font.family: Palette.font
    font.pixelSize: 14
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on color { ColorAnimation { duration: 220 } }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
