// ============================================================
// ClockWidget.qml — годинник на панелі
// ============================================================
import Quickshell
import "../core"
import QtQuick


// Віджет годинника на панелі — показує поточний час
HoverItem {
  id: root

  required property QtObject window

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  HoverText {
    id: label
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date, "HH:mm")
    palette: window.palette
    appConfig: window.appConfig
    normalColor: window.palette.widgetFg
    hoverColor: window.palette.green
    font.pixelSize: window.appConfig.scaled(14)
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
  }
}