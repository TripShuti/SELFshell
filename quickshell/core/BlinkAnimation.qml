// ============================================================
// core/BlinkAnimation.qml — повторюване блимання opacity
// ============================================================
import QtQuick

// Повторюване блимання прозорості батьківського елемента
// (running контролюється зовні). Замінює 4 ідентичні копії
// SequentialAnimation on opacity у віджетах.
SequentialAnimation {
  id: root

  property real minOpacity: 0.4
  property int blinkDuration: 600

  loops: Animation.Infinite

  // target прив'язуємо після створення: під час інстанціації
  // parent ще undefined і прямий біндинг дає warning
  Component.onCompleted: {
    fadeOut.target = parent
    fadeIn.target = parent
  }

  NumberAnimation {
    id: fadeOut
    property: "opacity"
    to: root.minOpacity
    duration: root.blinkDuration
    easing.type: Easing.InOutSine
  }
  NumberAnimation {
    id: fadeIn
    property: "opacity"
    to: 1.0
    duration: root.blinkDuration
    easing.type: Easing.InOutSine
  }
}
