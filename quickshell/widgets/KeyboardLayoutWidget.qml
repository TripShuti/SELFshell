// ============================================================
// quickshell/widgets/KeyboardLayoutWidget.qml — розкладка клавіатури на панелі
// ============================================================
import QtQuick
import "../core"

// Віджет розкладки клавіатури — показує поточну мову (UA, RU, US тощо).
// Стан (hyprctl + socket) живе в KeyboardLayoutState, тут лише вигляд:
// ЛКМ — наступна розкладка, ПКМ — попап зі списком (сигнал для Bar.qml).
HoverItem {
  id: root

  required property QtObject window
  signal openPopup(Item anchor)

  cursorShape: Qt.PointingHandCursor
  onClicked: kbState.cycleNext()
  onRightClicked: root.openPopup(root)

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
}
