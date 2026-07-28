// ============================================================
// ClockWidget.qml — годинник на панелі
// ============================================================
import Quickshell
import "../Palette.js" as Palette
import QtQuick


// Віджет годинника на панелі — показує поточний час (HH:mm)
Item {
  id: root

  signal clicked()
  property bool hovered: false

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  // Системний годинник з точністю до секунд (оновлюється кожну секунду)
  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // Текст часу — збільшується при наведенні
  Text {
    id: label
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color:  Palette.widgetFg
    font.family: Palette.font
    font.pixelSize: 14
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    scale: root.hovered ? 1.15 : 1.0

    Behavior on color { ColorAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
  }

  // Клік — відкриття календаря
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
