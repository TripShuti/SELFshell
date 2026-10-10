// ============================================================
// quickshell/core/BlinkAnimation.qml — повторюване блимання opacity
// ============================================================
import QtQuick

// Повторюване блимання прозорості явно переданого елемента
// (active контролюється зовні). Замінює 4 ідентичні копії
// SequentialAnimation on opacity у віджетах.
SequentialAnimation {
  id: root

  required property Item target
  property real minOpacity: 0.4
  property int blinkDuration: 600
  // Опційно: для глобального множника тривалостей анімацій
  property QtObject appConfig: null

  property bool active: false
  running: active && (!appConfig || appConfig.cfg.animationsEnabled)
  onRunningChanged: if (!running && fadeIn.target) fadeIn.target.opacity = 1

  loops: Animation.Infinite

  NumberAnimation {
    id: fadeOut
    target: root.target
    property: "opacity"
    to: root.minOpacity
    duration: root.appConfig ? root.appConfig.anim(root.blinkDuration) : root.blinkDuration
    easing.type: Easing.InOutSine
  }
  NumberAnimation {
    id: fadeIn
    target: root.target
    property: "opacity"
    to: 1.0
    duration: root.appConfig ? root.appConfig.anim(root.blinkDuration) : root.blinkDuration
    easing.type: Easing.InOutSine
  }
}
