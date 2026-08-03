// ============================================================
// ControlWidget.qml — кнопка центру сповіщень на панелі
// ============================================================
import "../core"
import QtQuick


// Віджет центру сповіщень — іконка + лічильник непрочитаних
HoverItem {
  id: root

  required property QtObject window

  property int unread: 0

  implicitWidth: txt.implicitWidth
  implicitHeight: parent?.height ?? 36

  HoverText {
    id: txt
    text: ""
    palette: window.palette
    color: {
      if (root.unread > 0) return window.palette.green
      if (root.hovered) return window.palette.light
      return window.palette.widgetFg
    }
    font.pixelSize: 19
    anchors.verticalCenter: parent.verticalCenter

    // Блимання при непрочитаних
    BlinkAnimation {
      running: root.unread > 0
      minOpacity: 0.4
      blinkDuration: 1000
    }
  }
}