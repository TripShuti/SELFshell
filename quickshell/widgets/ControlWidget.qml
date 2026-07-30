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
    SequentialAnimation on opacity {
      running: root.unread > 0
      loops: Animation.Infinite
      NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
    }
  }
}