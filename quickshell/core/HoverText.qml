// ============================================================
// quickshell/core/HoverText.qml — Text з hover-анімацією кольору та масштабу
// ============================================================
import QtQuick

Text {
  property QtObject palette: null
  // Опційно: для глобального множника тривалостей анімацій
  property QtObject appConfig: null
  property color normalColor: palette?.widgetFg ?? "#ede0d4"
  property color hoverColor: palette?.green ?? "#e79c06"
  property real hoverScale: 1.15
  property bool hovered: parent?.hovered ?? false
  // Легке "втискання" гліфа під час натискання (tactile feedback)
  property bool pressed: parent?.pressed ?? false

  color: hovered ? hoverColor : normalColor
  scale: pressed ? 0.92 : (hovered ? hoverScale : 1.0)

  Behavior on color { ColorAnimation { duration: appConfig ? appConfig.anim(220) : 220 } }
  Behavior on scale { NumberAnimation { duration: appConfig ? appConfig.anim(120) : 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
}