// ============================================================
// ControlWidget.qml — кнопка центру сповіщень на панелі
// ============================================================
import "../core"
import QtQuick


// Віджет центру сповіщень — іконка + лічильник непрочитаних
Item {
  id: root

  required property QtObject window
  signal clicked()

  property int unread: 0
  property bool hovered: false

  implicitWidth: txt.implicitWidth
  implicitHeight: parent?.height ?? 36

  Text {
    id: txt
    text: ""
    color: {
      if (root.unread > 0) return window.palette.green
      if (root.hovered) return window.palette.light
      return window.palette.widgetFg
    }
    font.family: window.palette.font
    font.pixelSize: 19
    anchors.verticalCenter: parent.verticalCenter
    scale: root.hovered ? 1.18 : 1.0

    Behavior on color { ColorAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

    // Блимання при непрочитаних
    SequentialAnimation on opacity {
      running: root.unread > 0
      loops: Animation.Infinite
      NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
