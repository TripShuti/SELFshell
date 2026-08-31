// ============================================================
// quickshell/widgets/KdeConnectWidget.qml — віджет телефону (kcd) на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts

// Віджет телефону: іконка + батарея + індикатор досяжності.
// Читає стан з window.kdeConnect (KdeConnectService в shell.qml).
Item {
  id: root

  required property QtObject window
  signal clicked()

  readonly property var svc: window ? window.kdeConnect : null
  readonly property bool installed: svc ? svc.installed : false
  readonly property bool reachable: svc ? svc.isReachable : false
  readonly property int charge: svc ? svc.batteryCharge : -1
  readonly property bool charging: svc ? svc.batteryCharging : false
  readonly property string devName: svc ? svc.primaryDeviceName : ""

  property bool hovered: false

  implicitWidth: row.implicitWidth
  implicitHeight: parent?.height ?? 36

  readonly property bool hasBattery: charge >= 0

  function batteryIcon(lvl) {
    var pct = lvl
    if (pct <= 15) return "\uF244"
    if (pct <= 50) return "\uF243"
    if (pct <= 80) return "\uF242"
    return "\uF240"
  }

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    // Іконка телефону
    Text {
      text: root.charging ? "\uF0E7" : (root.hasBattery ? batteryIcon(root.charge) : "\uF10B")
      color: {
        if (root.hovered) return window.palette.green
        if (!root.installed) return window.palette.mutedAlt
        if (root.charging) return window.palette.green
        if (root.hasBattery && root.charge <= 15) return window.palette.danger
        return root.reachable ? window.palette.fg : window.palette.mutedAlt
      }
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      scale: root.hovered ? 1.2 : 1.0
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
      Behavior on scale { NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
    }

    Text {
      visible: root.hasBattery && root.reachable
      text: root.charge + "%"
      color: {
        if (root.hovered) return window.palette.green
        if (root.charge <= 15 && !root.charging) return window.palette.danger
        return window.palette.fg
      }
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      scale: root.hovered ? 1.15 : 1.0
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
      Behavior on scale { NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
    }

    // Крапка досяжності — тільки конект, без індикації mute/dnd
    Rectangle {
      visible: root.installed
      width: 6; height: 6; radius: 3
      color: root.reachable ? window.palette.green : window.palette.mutedAlt
      opacity: root.reachable ? 1 : 0.5
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
      Behavior on opacity { NumberAnimation { duration: window.appConfig.anim(220) } }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.clicked()
  }
}
