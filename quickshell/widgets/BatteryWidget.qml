// ============================================================
// quickshell/widgets/BatteryWidget.qml — віджет заряду батареї на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../core"

// Віджет батареї: іконка + відсоток, червоний < 15% без зарядки.
// Дані та автоматика живуть в одному BatteryService для всіх моніторів.
HoverItem {
  id: root

  required property QtObject window
  readonly property var battery: window.battery
  readonly property int percent: battery.percent
  readonly property bool charging: battery.charging
  readonly property bool low: battery.low
  visible: battery.available
  cursorShape: Qt.PointingHandCursor
  onClicked: battery.refresh()
  implicitWidth: rowLayout.implicitWidth
  implicitHeight: parent?.height ?? 36

  readonly property string icon: {
    var p = root.percent
    if (p < 0) return "\uF097" // battery-unknown
    if (root.charging) return "\uF0E7" // bolt
    if (p < 13) return "\uF240"
    if (p < 38) return "\uF241"
    if (p < 63) return "\uF242"
    if (p < 88) return "\uF243"
    return "\uF244"
  }

  readonly property color iconColor: root.low ? window.palette.danger
      : root.charging ? window.palette.green
      : root.hovered ? window.palette.green
      : window.palette.fg

  RowLayout {
    id: rowLayout
    anchors.centerIn: parent
    spacing: 5
    scale: root.hovered ? 1.08 : 1.0
    Behavior on scale {
      NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }

    Text {
      text: root.icon
      color: root.iconColor
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    }
    Text {
      text: root.percent >= 0 ? root.percent + "%" : "--"
      color: root.iconColor
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    }
  }
}
