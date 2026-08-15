// ============================================================
// LauncherWidget.qml — кнопка лаунчера на панелі
// ============================================================
import "../core"
import QtQuick


// Кнопка відкриття лаунчера на панелі
HoverItem {
  id: root

  required property QtObject window

  implicitWidth: 28
  implicitHeight: parent?.height ?? 28

  HoverText {
    anchors.centerIn: parent
    text: "\uDB82\uDCC7"
    palette: window.palette
    normalColor: window.palette.widgetFg
    hoverColor: window.palette.green
    hoverScale: 1.2
    font.pixelSize: window.appConfig.scaled(18)
  }
}