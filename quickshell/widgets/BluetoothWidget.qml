// ============================================================
// BluetoothWidget.qml — віджет Bluetooth на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../Palette.js" as Palette

Item {
  id: root

  signal clicked()
  property bool hovered: false

  property BluetoothAdapter adapter: Bluetooth.defaultAdapter

  readonly property bool btEnabled: adapter?.enabled ?? false

  readonly property var connectedDevice: {
    if (!adapter || !adapter.devices) return null;
    let devs = adapter.devices.values;
    for (let i = 0; i < devs.length; i++) {
      if (devs[i] && devs[i].state === BluetoothDeviceState.Connected)
        return devs[i];
    }
    return null;
  }

  readonly property bool hasBattery: connectedDevice && connectedDevice.batteryAvailable
  readonly property int batteryLevel: hasBattery ? Math.round(connectedDevice.battery * 100) : 0

  implicitWidth: row.implicitWidth
  implicitHeight: parent?.height ?? 36

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Text {
      text: root.hasBattery
            ? batteryIcon(root.connectedDevice.battery)
            : ""

      color: {
        if (root.hovered) return Palette.green
        if (root.hasBattery) return batteryColor(root.connectedDevice.battery)
        return root.btEnabled && root.connectedDevice ? Palette.accent : Palette.mutedAlt
      }

      font.family: Palette.font
      font.pixelSize: 14
      scale: root.hovered ? 1.2 : 1.0

      Behavior on color { ColorAnimation { duration: 220 } }
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

      function batteryIcon(level) {
        var pct = (level || 0) * 100
        if (pct <= 15) return "\uF244"
        if (pct <= 50) return "\uF243"
        if (pct <= 80) return "\uF242"
        return "\uF240"
      }

      function batteryColor(level) {
        var pct = (level || 0) * 100
        return pct <= 15 ? Palette.danger : Palette.fg
      }
    }

    Text {
      visible: root.hasBattery
      text: batteryLevel + "%"

      color: {
        if (root.hovered) return Palette.green
        var pct = root.connectedDevice ? root.connectedDevice.battery * 100 : 0
        return pct <= 15 ? Palette.danger : Palette.fg
      }

      font.family: Palette.font
      font.pixelSize: 12
      scale: root.hovered ? 1.15 : 1.0

      Behavior on color { ColorAnimation { duration: 220 } }
      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
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
