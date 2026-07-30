// ============================================================
// core/HoverText.qml — Text з hover-анімацією кольору та масштабу
// ============================================================
import QtQuick

Text {
  property QtObject palette: null
  property color normalColor: palette?.widgetFg ?? "#ede0d4"
  property color hoverColor: palette?.green ?? "#e79c06"
  property real hoverScale: 1.15
  property bool hovered: parent?.hovered ?? false

  color: hovered ? hoverColor : normalColor
  scale: hovered ? hoverScale : 1.0

  Behavior on color { ColorAnimation { duration: 220 } }
  Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
}