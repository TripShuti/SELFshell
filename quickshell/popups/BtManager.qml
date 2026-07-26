// ============================================================
// BtManager.qml — менеджер Bluetooth: адаптер, пристрої,
// сканування
// ============================================================
import Quickshell
import Quickshell.Bluetooth
import "../"
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts


// Менеджер Bluetooth — адаптер, видимість, список пристроїв
AnimatedPopup {
  id: root
  bgOpacity: 0.88  // збережено індивідуальне значення, яке було локально в цьому попапі

  required property QtObject window

  implicitWidth: 380
  implicitHeight: layout.implicitHeight + 16
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  property BluetoothAdapter adapter: Bluetooth.defaultAdapter
  readonly property bool scanning: adapter?.discovering ?? false

  property int screenW: window ? window.screen.width : 1920
  property int screenH: window ? window.screen.height : 1080

  Component.onCompleted: {
    anchor.window = window
  }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      anchor.rect = Qt.rect(
        (screenW - implicitWidth) / 2,
        (screenH - implicitHeight) / 2,
        implicitWidth,
        implicitHeight
      )
    } else if (adapter?.discovering) {
      adapter.discovering = false
    }
  }


  ColumnLayout {
    id: layout
    x: 8
    y: 8
    width: parent.width - 16
    spacing: 8

    // Заголовок та тумблер Bluetooth
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "Bluetooth"
        color: Palette.accent
        font.family: Palette.font; font.pixelSize: 16; font.bold: true
        Layout.fillWidth: true
      }

      // Тумблер увімкнення Bluetooth
      Rectangle {
        id: btToggleBg
        property bool isHovered: false
        width: 36; height: 22; radius: 11
        color: adapter?.enabled ? Palette.widgetFg : Palette.bg2
        Behavior on color { ColorAnimation { duration: 150 } }
        border.width: isHovered ? 1 : 0
        border.color: Palette.hoverOverlay
        Behavior on border.width { NumberAnimation { duration: 120 } }

        Rectangle {
          x: adapter?.enabled ? parent.width - width - 2 : 2
          width: 18; height: 18; radius: 9
          color: adapter?.enabled ? Palette.bg1 : Palette.gray
          anchors.verticalCenter: parent.verticalCenter
          Behavior on x { NumberAnimation { duration: 150 } }
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: btToggleBg.isHovered = true
          onExited: btToggleBg.isHovered = false
          onClicked: { if (adapter) adapter.enabled = !adapter.enabled }
        }
      }
    }

    // Інформація про адаптер та кнопка сканування
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: adapter?.name ?? "No adapter"
        color: Palette.mutedAlt
        font.family: Palette.font; font.pixelSize: 12
        Layout.fillWidth: true
      }

      // Кнопка сканування (блимає під час пошуку)
      Rectangle {
        property bool hovered: false
        implicitWidth: scanLabel.implicitWidth + 16; height: 24; radius: 4
        color: scanning ? Palette.danger : (hovered ? Palette.hoverOverlay : Palette.bgLayer)
        Behavior on color { ColorAnimation { duration: 150 } }

        SequentialAnimation on opacity {
          running: scanning
          loops: Animation.Infinite
          NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }

        Text {
          id: scanLabel
          anchors.centerIn: parent
          text: scanning ? "Scanning..." : "Scan"
          color: Palette.textLight
          font.family: Palette.font; font.pixelSize: 11
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: {
            if (adapter) adapter.discovering = !adapter.discovering
          }
        }
      }
    }

    // Тумблер видимості (Discoverable)
    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      visible: adapter?.enabled ?? false

      Text {
        text: "Discoverable"
        color: Palette.textLight
        font.family: Palette.font; font.pixelSize: 12
      }

      Rectangle {
        id: discoverableToggleBg
        property bool isHovered: false
        width: 32; height: 18; radius: 9
        color: adapter?.discoverable ? Palette.widgetFg : Palette.bg2
        Behavior on color { ColorAnimation { duration: 150 } }
        border.width: isHovered ? 1 : 0
        border.color: Palette.hoverOverlay
        Behavior on border.width { NumberAnimation { duration: 120 } }

        Rectangle {
          x: adapter?.discoverable ? parent.width - width - 2 : 2
          width: 14; height: 14; radius: 7
          color: adapter?.discoverable ? Palette.bg1 : Palette.gray
          anchors.verticalCenter: parent.verticalCenter
          Behavior on x { NumberAnimation { duration: 150 } }
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: discoverableToggleBg.isHovered = true
          onExited: discoverableToggleBg.isHovered = false
          onClicked: { if (adapter) adapter.discoverable = !adapter.discoverable }
        }
      }

      Item { Layout.fillWidth: true }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Palette.accent
      opacity: 0.3
    }

    // Заголовок списку пристроїв
    Text {
      text: "Devices"
      color: Palette.accent
      font.family: Palette.font; font.pixelSize: 12; font.bold: true
    }

    // Список Bluetooth пристроїв
    Repeater {
      model: ScriptModel {
        values: adapter ? [...adapter.devices.values].sort((a, b) => {
          if (a.connected && !b.connected) return -1;
          if (b.connected && !a.connected) return 1;
          if (a.bonded && !b.bonded) return -1;
          if (b.bonded && !a.bonded) return 1;
          return (a.name || "").localeCompare(b.name || "");
        }) : []
      }

      delegate: Item {
        id: device
        required property BluetoothDevice modelData

        readonly property bool devConnected: modelData && modelData.state === BluetoothDeviceState.Connected
        readonly property bool devLoading: modelData && (modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting)

        height: 48
        Layout.fillWidth: true

        RowLayout {
          anchors.fill: parent
          spacing: 6

          // Назва пристрою + статус
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: modelData.name || modelData.deviceName || modelData.address
              color: Palette.textLight
              font.family: Palette.font; font.pixelSize: 12
              elide: Text.ElideRight
              Layout.fillWidth: true
              opacity: device.devLoading ? 0.5 : 1
            }

            RowLayout {
              spacing: 4

              Text {
                text: {
                  if (device.devConnected) return "Connected"
                  if (device.devLoading) return modelData.state === BluetoothDeviceState.Connecting ? "Connecting..." : "Disconnecting..."
                  if (modelData.paired) return "Paired"
                  return modelData.address
                }
                color: device.devConnected ? Palette.accent : Palette.mutedAlt
                font.family: Palette.font; font.pixelSize: 10
                opacity: device.devLoading ? 0.5 : 1
              }

              // Рівень заряду пристрою (навушники, миша тощо), якщо девайс його повідомляє
              Text {
                visible: device.devConnected && modelData.batteryAvailable
                text: "• " + batteryIcon(modelData.battery) + " " + Math.round((modelData.battery || 0) * 100) + "%"
                color: batteryColor(modelData.battery)
                font.family: Palette.font; font.pixelSize: 10
                opacity: device.devLoading ? 0.5 : 1

                function batteryIcon(level) {
                  var pct = (level || 0) * 100
                  if (pct <= 15) return "\uF244"
                  if (pct <= 50) return "\uF243"
                  if (pct <= 80) return "\uF242"
                  return "\uF240"
                }

                function batteryColor(level) {
                  var pct = (level || 0) * 100
                  return pct <= 15 ? Palette.danger : Palette.mutedAlt
                }
              }
            }
          }

          // Кнопка дії: Pair / Connect / Disconnect
          Rectangle {
            property bool hovered: false
            implicitWidth: actionLabel.implicitWidth + 12; height: 24; radius: 4
            color: device.devConnected ? Palette.bgLayer : (modelData.pairing ? Palette.yellow : (modelData.paired ? (hovered ? Palette.widgetFg : Palette.accent) : (hovered ? Palette.hoverOverlay : Palette.bgLayer)))
            Behavior on color { ColorAnimation { duration: 150 } }
            opacity: device.devLoading ? 0.5 : 1
            enabled: !device.devLoading

            Text {
              id: actionLabel
              anchors.centerIn: parent
              text: {
                if (device.devConnected) return "Disconnect"
                if (modelData.pairing) return "Cancel"
                if (modelData.paired) return "Connect"
                return "Pair"
              }
              color: modelData.paired && !device.devConnected ? Palette.bgLayer : Palette.textLight
              font.family: Palette.font; font.pixelSize: 10
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: {
                if (device.devLoading)
                  return
                if (device.devConnected)
                  modelData.disconnect()
                else if (modelData.pairing)
                  modelData.cancelPair()
                else if (modelData.paired)
                  modelData.connect()
                else
                  modelData.pair()
              }
            }
          }

          // Кнопка забути пристрій
          Rectangle {
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: hovered ? Palette.hoverOverlay : Palette.bgLayer
            Behavior on color { ColorAnimation { duration: 150 } }
            visible: modelData.paired
            Text {
              anchors.centerIn: parent
              text: "\u2716"
              color: Palette.danger
              font.family: Palette.font; font.pixelSize: 12
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: modelData.forget()
            }
          }
        }
      }
    }

    // Стан: пристроїв не знайдено
    Text {
      text: adapter && adapter.devices.values.length === 0 ? "No devices" : ""
      color: Palette.mutedAlt
      font.family: Palette.font; font.pixelSize: 12
      visible: adapter != null
    }

    // Стан: адаптер недоступний
    Text {
      text: adapter == null ? "Bluetooth adapter not available" : ""
      color: Palette.danger
      font.family: Palette.font; font.pixelSize: 12
      visible: adapter == null
    }
  }

}
