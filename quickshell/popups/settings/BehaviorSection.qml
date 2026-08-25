// ============================================================
// settings/BehaviorSection.qml — розділ Behavior: DND, idle-таймаути,
// кроки колеса, скидання до заводських налаштувань
// ============================================================
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac
  readonly property var window: sys.window

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 16

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Notifications" }
      SetToggle {
        sys: root.sys
        label: "Do not disturb"
        sub: "Hides all notifications (toast, list, sound)."
        on: root.cfg.dndEnabled
        onToggled: v => { root.cfg.dndEnabled = v; root.ac.saveToFile() }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Idle timeouts, seconds" }
      NumField { label: "Lock (0 = never)"; prop: "idleLockTimeout"; stepSize: 30; minVal: 0; maxVal: 86400 }
      NumField { label: "DPMS off (0 = never)"; prop: "idleDpmsTimeout"; stepSize: 30; minVal: 0; maxVal: 86400 }
      NumField { label: "Suspend (0 = never)"; prop: "idleSuspendTimeout"; stepSize: 30; minVal: 0; maxVal: 86400 }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Wheel steps" }
      NumField { label: "Audio volume"; prop: "audioStep"; stepSize: 0.05; minVal: 0.01; maxVal: 0.5; decimals: 2 }
      NumField { label: "Brightness"; prop: "brightnessStep"; stepSize: 1; minVal: 1; maxVal: 25 }
      Text {
        text: "All settings apply immediately."
        color: window.palette.mutedAlt
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Defaults" }
      SetButton {
        sys: root.sys
        text: "Reset all settings to defaults"
        onClicked: root.ac.resetCfg()
      }
    }
  }

  // Числовий степпер для налаштувань поведінки.
  // Змінює cfg[prop] і одразу зберігає в config.json.
  // idle-таймаути підтискаються, щоб зберігалося lock < dpms < suspend;
  // 0 = "never" (рівень вимкнено, обмеження порядку не застосовуються).
  component NumField: RowLayout {
    id: field
    required property string label
    required property string prop
    property real stepSize: 1
    property real minVal: 0
    property real maxVal: 9999
    property int decimals: 0
    spacing: 4
    Layout.fillWidth: true

    Text {
      text: field.label
      color: root.window.palette.fg
      font.family: root.window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    Rectangle {
      implicitWidth: 18
      implicitHeight: 18
      radius: 3
      color: fieldMouseMin.pressed ? root.window.palette.bgAlpha : root.window.palette.bg2
      Behavior on color { ColorAnimation { duration: root.ac.anim(120) } }
      Text { anchors.centerIn: parent; text: "\u2212"; color: root.window.palette.fg; font.pixelSize: window.appConfig.scaled(11); font.bold: true }
      MouseArea {
        id: fieldMouseMin
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: field.setValue(-1)
      }
    }

    Text {
      text: root.cfg[field.prop].toFixed(field.decimals)
      color: root.window.palette.fg
      font.family: root.window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      horizontalAlignment: Text.AlignHCenter
      Layout.preferredWidth: 46
    }

    Rectangle {
      implicitWidth: 18
      implicitHeight: 18
      radius: 3
      color: fieldMousePlus.pressed ? root.window.palette.bgAlpha : root.window.palette.bg2
      Behavior on color { ColorAnimation { duration: root.ac.anim(120) } }
      Text { anchors.centerIn: parent; text: "+"; color: root.window.palette.fg; font.pixelSize: window.appConfig.scaled(11); font.bold: true }
      MouseArea {
        id: fieldMousePlus
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: field.setValue(1)
      }
    }

    function setValue(dir) {
      var cur = root.cfg[field.prop]
      var next = cur + dir * field.stepSize
      if (field.prop === "idleLockTimeout") {
        // 0 = never (вимкнено); інакше lock має бути меншим за dpms
        if (next !== 0 && root.cfg.idleDpmsTimeout > 0)
          next = Math.min(next, root.cfg.idleDpmsTimeout - 1)
      } else if (field.prop === "idleDpmsTimeout") {
        // 0 = never (вимкнено); інакше dpms має бути між lock+1 і suspend-1
        if (next !== 0) {
          if (root.cfg.idleLockTimeout > 0)
            next = Math.max(next, root.cfg.idleLockTimeout + 1)
          if (root.cfg.idleSuspendTimeout > 0)
            next = Math.min(next, root.cfg.idleSuspendTimeout - 1)
        }
      } else if (field.prop === "idleSuspendTimeout") {
        // 0 = never (вимкнено); інакше suspend має бути більшим за dpms
        if (next !== 0 && root.cfg.idleDpmsTimeout > 0)
          next = Math.max(next, root.cfg.idleDpmsTimeout + 1)
      }
      next = Math.round(next / field.stepSize) * field.stepSize
      next = Math.min(Math.max(next, field.minVal), field.maxVal)
      root.cfg[field.prop] = next
      root.ac.saveToFile()
    }
  }
}
