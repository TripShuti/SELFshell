// ============================================================
// BluetoothPopup.qml — менеджер Bluetooth: адаптер, пристрої,
// сканування
// ============================================================
import Quickshell
import Quickshell.Bluetooth
import "../core"
import QtQuick
import QtQuick.Layouts


// Менеджер Bluetooth — адаптер, видимість, список пристроїв
AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 380
  implicitHeight: layout.implicitHeight + 16
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  property BluetoothAdapter adapter: Bluetooth.defaultAdapter
  readonly property bool scanning: adapter?.discovering ?? false

  // Ревізія для пересортвання: біндинг ScriptModel.values залежить лише
  // від складу списку — зміни connected/paired пристроїв його не чіпають
  property int sortRev: 0
  Timer {
    running: root.visible
    interval: 1000
    repeat: true
    onTriggered: root.sortRev++
  }

  property int screenW: window ? window.screen.width : 1920
  property int screenH: window ? window.screen.height : 1080

  Component.onCompleted: {
    anchor.window = window
    // Політика "режиму парингу": поки Discoverable вимкнений, адаптер
    // не приймає вхідний паринг узагалі — чужий пристрій не може навіть
    // почати підключення поза вікном видимості. Вже спарені пристрої
    // реконектяться і без pairable
    if (adapter && !adapter.discoverable) adapter.pairable = false
  }

  // DiscoverableTimeout сам скидає discoverable через таймаут — гасимо
  // pairable слідом, щоб "режим парингу" завжди закривався цілком
  Connections {
    // адаптер може з'явитись/зникнути динамічно (USB-донгл) — біндинг на
    // властивість, а не на об'єкт
    target: root.adapter
    function onDiscoverableChanged() {
      if (root.adapter && !root.adapter.discoverable) root.adapter.pairable = false
    }
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
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(16); font.bold: true
        Layout.fillWidth: true
      }

      // Тумблер увімкнення Bluetooth
      ToggleSwitch {
        checked: adapter?.enabled ?? false
        palette: window.palette
        appConfig: window.appConfig
        checkedColor: window.palette.widgetFg
        Layout.alignment: Qt.AlignVCenter
        onToggled: value => { if (adapter) adapter.enabled = value }
      }
    }

    // Інформація про адаптер та кнопка сканування
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: adapter?.name ?? "No adapter"
        color: window.palette.mutedAlt
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
        Layout.fillWidth: true
      }

      // Кнопка сканування (блимає під час пошуку)
      Rectangle {
        property bool hovered: false
        implicitWidth: scanLabel.implicitWidth + 16; height: 24; radius: 4
        color: scanning ? window.palette.danger : (hovered ? window.palette.hoverOverlay : window.palette.bgLayer)
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

        SequentialAnimation on opacity {
          running: scanning
          loops: Animation.Infinite
          NumberAnimation { to: 0.5; duration: appConfig.anim(800); easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.0; duration: appConfig.anim(800); easing.type: Easing.InOutSine }
        }

        Text {
          id: scanLabel
          anchors.centerIn: parent
          text: scanning ? "Scanning..." : "Scan"
          color: window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
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
        color: window.palette.textLight
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
      }

      ToggleSwitch {
        checked: adapter?.discoverable ?? false
        palette: window.palette
        appConfig: window.appConfig
        checkedColor: window.palette.widgetFg
        trackWidth: 32; trackHeight: 18; knobSize: 14
        Layout.alignment: Qt.AlignVCenter
        onToggled: value => {
          if (!adapter) return
          adapter.discoverable = value
          // pairable слідує за discoverable: тумблер = "режим парингу"
          adapter.pairable = value
        }
      }

      Item { Layout.fillWidth: true }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: window.palette.accent
      opacity: 0.3
    }

    // Заголовок списку пристроїв
    Text {
      text: "Devices"
      color: window.palette.accent
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
    }

    // Список Bluetooth пристроїв
      Repeater {
        model: ScriptModel {
          values: {
            root.sortRev // залежність: пересортовувати при змінах стану пристроїв
            return adapter ? [...adapter.devices.values].sort((a, b) => {
              if (a.connected && !b.connected) return -1;
              if (b.connected && !a.connected) return 1;
              if (a.bonded && !b.bonded) return -1;
              if (b.bonded && !a.bonded) return 1;
              return (a.name || "").localeCompare(b.name || "");
            }) : []
          }
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
              color: window.palette.textLight
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
              elide: Text.ElideRight
              Layout.fillWidth: true
              opacity: device.devLoading ? 0.5 : 1
              Behavior on opacity { NumberAnimation { duration: window.appConfig.anim(150); easing.type: Easing.OutCubic } }
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
                color: device.devConnected ? window.palette.accent : window.palette.mutedAlt
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
                opacity: device.devLoading ? 0.5 : 1
              Behavior on opacity { NumberAnimation { duration: window.appConfig.anim(150); easing.type: Easing.OutCubic } }
              }

              // Рівень заряду пристрою (навушники, миша тощо), якщо девайс його повідомляє
              Text {
                visible: device.devConnected && modelData.batteryAvailable
                text: "• " + batteryIcon(modelData.battery) + " " + Math.round((modelData.battery || 0) * 100) + "%"
                color: batteryColor(modelData.battery)
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
                opacity: device.devLoading ? 0.5 : 1
              Behavior on opacity { NumberAnimation { duration: window.appConfig.anim(150); easing.type: Easing.OutCubic } }

                function batteryIcon(level) {
                  var pct = (level || 0) * 100
                  if (pct <= 15) return "\uF244"
                  if (pct <= 50) return "\uF243"
                  if (pct <= 80) return "\uF242"
                  return "\uF240"
                }

                function batteryColor(level) {
                  var pct = (level || 0) * 100
                  return pct <= 15 ? window.palette.danger : window.palette.mutedAlt
                }
              }
            }
          }

          // Кнопка дії: Pair / Connect / Disconnect
          Rectangle {
            property bool hovered: false
            implicitWidth: actionLabel.implicitWidth + 12; height: 24; radius: 4
            color: device.devConnected ? window.palette.bgLayer : (modelData.pairing ? window.palette.yellow : (modelData.paired ? (hovered ? window.palette.widgetFg : window.palette.accent) : (hovered ? window.palette.hoverOverlay : window.palette.bgLayer)))
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
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
              color: modelData.paired && !device.devConnected ? window.palette.bgLayer : window.palette.textLight
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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

          // Довіра пристрою: trusted-пристрої підключають сервіси без
          // запиту авторизації. Клік перемикає Device1.Trusted на місці —
          // не лише в момент парингу
          Rectangle {
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: hovered ? window.palette.hoverOverlay : window.palette.bgLayer
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
            visible: modelData.paired

            HoverText {
              anchors.centerIn: parent
              // замок: закритий — довіряємо, відкритий — ні
              text: modelData.trusted ? "\uF023" : "\uF09C"
              palette: window.palette
              appConfig: window.appConfig
              normalColor: modelData.trusted ? window.palette.accent : window.palette.mutedAlt
              hovered: parent.hovered
              font.pixelSize: appConfig.scaled(11)
            }

            MouseArea {
              id: trustArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: modelData.trusted = !modelData.trusted
            }
          }

          // Кнопка забути пристрій
          Rectangle {
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: hovered ? window.palette.hoverOverlay : window.palette.bgLayer
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
            visible: modelData.paired
            Text {
              anchors.centerIn: parent
              text: "\u2716"
              color: window.palette.danger
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
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
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
      visible: adapter != null
    }

    // Стан: адаптер недоступний
    Text {
      text: adapter == null ? "Bluetooth adapter not available" : ""
      color: window.palette.danger
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
      visible: adapter == null
    }
  }

}
