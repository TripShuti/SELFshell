// ============================================================
// AnimatedPopup.qml — базове анімоване попап-вікно для всіх
// спливаючих панелей
// ============================================================
import "Palette.js" as Palette
import Quickshell
import QtQuick

// Базове анімоване попап-вікно для всіх спливаючих панелей
PopupWindow {
  id: root

  // Налаштовувані кольори та параметри анімації
  property color bgColor: Palette.bg0H
  property real bgOpacity: 0.88
  property real bgLighten: 1.5
  property real cornerRadius: 12
  property color borderColor: Palette.bg2
  property real enterScale: 0.85
  property real overshootAmount: 2.5
  property int enterDuration: 350
  property int exitDuration: 120
  property int transformOrigin: Item.Top
  property real slideDistance: 10

  default property alias content: container.data

  color: "transparent"
  grabFocus: true

  // Закриває попап з анімацією
  function close() {
    if (exitAnim.running) return
    exitAnim.start()
  }

  // Перемикає видимість попапа
  function toggle() {
    root.visible = !root.visible
  }

  // Зовнішнє м'яке сяйво навколо контейнера.
  // Раніше виходило на -3px за межі container через anchors.margins,
  // але сама Wayland-поверхня (PopupWindow) має розмір рівно container-а —
  // ці зайві пікселі обрізались поверхнею під прямим кутом, лишаючи
  // гострі "недорізані" клинки заокругленого сяйва по кутах попапу.
  Rectangle {
    id: outerGlow
    anchors.fill: container
    radius: container.radius
    color: root.borderColor
    opacity: 0.10
    scale: container.scale
    transformOrigin: root.transformOrigin
  }

  // Контейнер — тільки трансформація (масштаб/зсув/fade) і рамка.
  // Сам по собі прозорий: реальний фон живе в окремому bgRect нижче,
  // щоб анімація входу/виходу не конфліктувала зі стабільною
  // непрозорістю фону (раніше обидві боролись за container.opacity).
  Rectangle {
    id: container
    anchors.fill: parent
    radius: root.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: root.borderColor
    opacity: 0.50
    scale: root.enterScale
    transformOrigin: root.transformOrigin
    clip: true
    transform: Translate { id: animY; y: 0 }

    // Реальний фон попапу — єдина спільна точка керування для ВСІХ
    // попапів. Змінюєш bgColor/bgOpacity/bgLighten тут в AnimatedPopup —
    // застосовується одразу до кожного попапу, без дублікатів по файлах.
    Rectangle {
      id: bgRect
      anchors.fill: parent
      radius: parent.radius
      opacity: root.bgOpacity
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(root.bgColor, root.bgLighten) }
        GradientStop { position: 1.0; color: root.bgColor }
      }
    }

    // Внутрішній border (тонка обводка всередині контейнера)
    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: parent.radius - 1
      color: "transparent"
      border.width: 1
      border.color: root.borderColor
      opacity: 0.55 * 0.35
    }

    // Підсвітка верхнього краю
    Rectangle {
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.hoverOverlay }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    // Невидимий фокус-менеджер для клавіатури
    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
      onVisibleChanged: if (visible) forceActiveFocus()
    }

    // Анімація появи — прозорість + масштаб + зсув
    ParallelAnimation {
      id: enterAnim
      NumberAnimation {
        target: container; property: "opacity"
        from: 0; to: 1
        duration: 120; easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: container; property: "scale"
        from: root.enterScale; to: 1.0
        duration: root.enterDuration
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: animY; property: "y"
        from: -root.slideDistance; to: 0
        duration: root.enterDuration
        easing.type: Easing.OutBack
        easing.overshoot: root.overshootAmount
      }
    }

    // Анімація закриття — зворотний порядок
    SequentialAnimation {
      id: exitAnim
      ParallelAnimation {
        NumberAnimation {
          target: container; property: "opacity"
          to: 0; duration: root.exitDuration; easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: container; property: "scale"
          to: 0.85; duration: root.exitDuration; easing.type: Easing.InCubic
        }
        NumberAnimation {
          target: animY; property: "y"
          to: -root.slideDistance
          duration: root.exitDuration
          easing.type: Easing.InCubic
        }
      }
      ScriptAction { script: root.visible = false }
    }
  }

  // Запуск анімації появи при відкритті
  onVisibleChanged: {
    if (visible) {
      if (exitAnim.running) exitAnim.stop()
      container.opacity = 0
      container.scale = root.enterScale
      animY.y = -root.slideDistance
      enterAnim.start()
    }
  }
}
