// ============================================================
// quickshell/widgets/KeyboardLayoutWidget.qml — розкладка клавіатури на панелі
// ============================================================
import QtQuick
import "../core"

// Віджет розкладки клавіатури — показує поточну мову (UA, RU, US тощо).
// Стан (hyprctl + socket) живе в KeyboardLayoutState, тут лише вигляд:
// ЛКМ — наступна розкладка, ПКМ — попап зі списком (сигнал для Bar.qml).
Item {
  id: root

  required property QtObject window
  signal openPopup(Item anchor)

  // Hover-стан для фідбеку (HoverText-рецепт: колір + масштаб)
  property bool hovered: false

  implicitWidth: txt.implicitWidth
  implicitHeight: parent?.height ?? 36

  // Вимкнений в Settings віджет лишається живим в Loader-і навмисно
  // (PillBar без thrash) — сокет і hyprctl гейтимо по cfg напряму,
  // а не по visible (власний флаг не бачить прихованого предка)
  readonly property bool widgetEnabled: window.appConfig.cfg.keyboardEnabled

  KeyboardLayoutState {
    id: kbState
    monitor: root.widgetEnabled
  }

  Text {
    id: txt
    text: kbState.displayText
    color: root.hovered ? window.palette.green : window.palette.widgetFg
    font.family: window.palette.font
    font.pixelSize: window.appConfig.scaled(14)
    anchors.verticalCenter: parent.verticalCenter
    scale: root.hovered ? 1.08 : 1.0

    Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    Behavior on scale {
      NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) kbState.cycleNext()
      else root.openPopup(root)
    }
  }
}
