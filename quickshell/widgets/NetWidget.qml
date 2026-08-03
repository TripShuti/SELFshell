// ============================================================
// NetWidget.qml — віджет мережі на панелі
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../core"

// Віджет мережі на панелі — іконка Wi-Fi/Ethernet
HoverItem {
  id: root

  required property QtObject window

  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []

  readonly property var wiredDevice: {
    for (let i = 0; i < networkDevices.length; i++) {
      let dev = networkDevices[i];
      if (dev && dev.type === DeviceType.Wired) return dev;
    }
    return null;
  }

  readonly property var wifiDevice: {
    for (let i = 0; i < networkDevices.length; i++) {
      if (networkDevices[i] && networkDevices[i].type === DeviceType.Wifi) {
        return networkDevices[i];
      }
    }
    return null;
  }

  readonly property var connectedWifi: {
    if (!wifiDevice || !wifiDevice.networks) return null;
    let nets = wifiDevice.networks.values;
    for (let i = 0; i < nets.length; i++) {
      if (nets[i] && nets[i].connected) return nets[i];
    }
    return null;
  }

  readonly property bool hasWired: wiredDevice?.connected ?? false
  readonly property bool hasWifi: connectedWifi != null

  readonly property real signalStrength: hasWifi ? (connectedWifi.signalStrength || 0) : 0

  readonly property int signalBars: {
    var pct = Math.max(0, Math.min(100, Math.round((signalStrength || 0) * 100)));
    if (pct <= 0) return 0;
    return Math.max(1, Math.min(4, Math.ceil(pct / 25)));
  }

  readonly property var wifiIcons: ["󰤭", "󰤯", "󰤟", "󰤢", "󰤨"]

  readonly property string mainIcon: {
    if (hasWired) return "󰈀";
    if (hasWifi) return root.wifiIcons[signalBars];
    return "󰤭";
  }

  readonly property color iconColor: {
    if (root.hovered) return window.palette.green;
    if (hasWired || hasWifi) return window.palette.fg;
    return window.palette.mutedAlt;
  }

  implicitWidth: row.implicitWidth
  implicitHeight: parent?.height ?? 36

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    HoverText {
      text: root.mainIcon
      palette: window.palette
      hoverScale: 1.2
      color: root.iconColor
    }
  }
}