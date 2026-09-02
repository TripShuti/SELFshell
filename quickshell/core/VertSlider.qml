// ============================================================
// quickshell/core/VertSlider.qml — вертикальний слайдер для еквалайзера: трек із заливкою знизу, кругла ручка, drag + колесо
// ============================================================
import QtQuick

Item {
  id: root

  property real from: -12
  property real to: 12
  property real step: 1
  property real value: 0
  property string label: ""
  property color trackColor: "#00000000"
  property color fillColor: "#00000000"
  property color knobColor: "#00000000"
  property color labelColor: "#00000000"
  property string fontFamily: "monospace"
  property int fontPx: 9

  signal moved(real value)

  readonly property bool dragging: ma.pressed
  // Внутрішнє значення під час drag — не рве зовнішній біндинг value,
  // зовні оновлюється через moved → батько міняє bands → value
  property real _dragValue: value
  readonly property real _displayValue: dragging ? _dragValue : value
  onValueChanged: if (!dragging) _dragValue = value
  onDraggingChanged: if (dragging) _dragValue = value

  implicitWidth: 26
  implicitHeight: 120

  Rectangle {
    id: track
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: bandLabel.bottom
    anchors.topMargin: 4
    anchors.bottom: valueLabel.top
    anchors.bottomMargin: 4
    width: 6
    radius: 3
    color: root.trackColor
    // без clip заливка/ручка на крайніх значеннях міліметрово
    // виходили за трек (radius-кути) і напливали на сусідні елементи
    clip: true

    Rectangle {
      id: fill
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: (root.to !== root.from) ? track.height * (root._displayValue - root.from) / (root.to - root.from) : 0
      radius: 3
      color: root.fillColor
    }

    Rectangle {
      id: knob
      width: 16
      height: 8
      radius: 3
      color: root.knobColor
      anchors.horizontalCenter: parent.horizontalCenter
      // кламп у межах треку: на краях діапазону ручка виступала
      // на height/2 за межі і напливала на сусідні елементи
      y: Math.max(0, Math.min(track.height - height,
        track.height - fill.height - height / 2))
    }
  }

  Text {
    id: valueLabel
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    text: Math.round(root._displayValue)
    color: root.labelColor
    font.family: root.fontFamily
    font.pixelSize: root.fontPx
  }

  Text {
    id: bandLabel
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    text: root.label
    color: root.labelColor
    font.family: root.fontFamily
    font.pixelSize: root.fontPx
  }

  MouseArea {
    id: ma
    anchors.fill: track
    anchors.topMargin: -6
    anchors.bottomMargin: 0
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    function apply(y) {
      var t = 1 - Math.max(0, Math.min(1, (y - knob.height / 2) / (track.height - knob.height)))
      var raw = root.from + t * (root.to - root.from)
      var v = Math.round(raw / root.step) * root.step
      v = Math.max(root.from, Math.min(root.to, v))
      if (v !== root._dragValue) {
        root._dragValue = v
        root.moved(v)
      }
    }

    onPressed: apply(mouse.y)
    onPositionChanged: if (pressed) apply(mouse.y)
    onWheel: wheel => {
      if (wheel.angleDelta.y === 0) return
      var base = root.dragging ? root._dragValue : root.value
      var v = base + (wheel.angleDelta.y > 0 ? root.step : -root.step)
      v = Math.max(root.from, Math.min(root.to, v))
      v = Math.round(v / root.step) * root.step
      root._dragValue = v
      root.moved(v)
    }
  }
}
