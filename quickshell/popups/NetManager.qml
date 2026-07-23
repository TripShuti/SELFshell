// ============================================================
// NetManager.qml — менеджер мереж: Wi-Fi, Ethernet, сканування
// ============================================================
import Quickshell
import Quickshell.Networking
import Quickshell.Io
import "../"
import "../Palette.js" as Palette
import QtQuick
import QtQuick.Layouts

// Менеджер мереж — Wi-Fi та Ethernet з'єднання, сканування, налаштування
AnimatedPopup {
  id: root
  bgOpacity: 0.88  // збережено індивідуальне значення, яке було локально в цьому попапі

  required property QtObject window

  implicitWidth: 380
  implicitHeight: layout.implicitHeight + 16
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  property var pendingNetwork: null
  property var settingsNetwork: null
  property string settingsConnKind: "wifi"
  property string settingsDeviceName: ""

  NetworkConnectionSettings {
    id: connectionSettings
    window: root.window
    network: root.settingsNetwork
    connKind: root.settingsConnKind
    deviceName: root.settingsDeviceName
  }

  // Відкриває налаштування Wi-Fi мережі
  function openWifiSettings(net) {
    root.settingsNetwork = net;
    root.settingsConnKind = "wifi";
    root.settingsDeviceName = root.wifiDevice ? root.wifiDevice.name : "";
    root.visible = false;
    connectionSettings.visible = true;
  }

  // Відкриває налаштування Ethernet
  function openEthernetSettings() {
    root.settingsNetwork = {
      name: root.wiredDevice ? root.wiredDevice.name : "",
      connected: root.wiredDevice ? root.wiredDevice.connected : false
    };
    root.settingsConnKind = "ethernet";
    root.settingsDeviceName = root.wiredDevice ? root.wiredDevice.name : "";
    root.visible = false;
    connectionSettings.visible = true;
  }

  Process {
    id: wiredProcess
  }

  readonly property bool backendAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  
  // Знаходить перший Wi-Fi пристрій
  readonly property var wifiDevice: {
    var devices = networkDevices || [];
    for (var i = 0; i < devices.length; i++) {
        if (devices[i] && devices[i].type === DeviceType.Wifi)
            return devices[i];
    }
    return null;
  }

  // Знаходить перший дротовий пристрій
  readonly property var wiredDevice: {
    var devices = networkDevices || [];
    for (var i = 0; i < devices.length; i++) {
        var dev = devices[i];
        if (dev && (dev.type === 2 || (dev.name && (dev.name.startsWith("en") || dev.name.startsWith("eth"))))) {
            return dev;
        }
    }
    return null;
  }
  
  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false

  // Конвертує силу сигналу (0-1) в рівень (1-4)
  function signalBars(strength) {
    var percent = Math.max(0, Math.min(100, Math.round((strength || 0) * 100)));
    if (percent <= 0) return 1;
    return Math.max(1, Math.min(4, Math.ceil(percent / 25)));
  }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      anchor.rect = Qt.rect(
        (window.screen.width - implicitWidth) / 2,
        (window.screen.height - implicitHeight) / 2,
        implicitWidth,
        implicitHeight
      )
      if (wifiDevice && wifiEnabled) wifiDevice.scannerEnabled = true;
    } else {
      if (wifiDevice) wifiDevice.scannerEnabled = false;
      pendingNetwork = null;
    }
  }

  Component.onCompleted: anchor.window = window


  ColumnLayout {
    id: layout
    x: 8
    y: 8
    width: parent.width - 16
    spacing: 8

    // --- Дротове з'єднання (Ethernet) ---
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6
      visible: root.wiredDevice !== null && root.pendingNetwork === null

      // Заголовок та статус
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "Wired"
          color: Palette.accent
          font.family: Palette.font; font.pixelSize: 16; font.bold: true
          Layout.fillWidth: true
        }
        
        Text {
          text: root.wiredDevice?.connected ? "Connected" : "Disconnected"
          color: root.wiredDevice?.connected ? Palette.accent : Palette.mutedAlt
          font.family: Palette.font; font.pixelSize: 14
        }
      }

      // Назва інтерфейсу + кнопки
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: root.wiredDevice?.name || "Wired Interface"
          color: Palette.textLight
          font.family: Palette.font; font.pixelSize: 14
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        // Кнопка налаштувань
        Rectangle {
          id: settingsBtn
          property bool hovered: false
          implicitWidth: settingsLabel.implicitWidth + 12; height: 24; radius: 4
color: hovered ? Palette.hoverOverlay : Palette.bgLayer
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              id: settingsLabel
            anchors.centerIn: parent
            text: "Settings"
            color: Palette.textLight
            font.family: Palette.font; font.pixelSize: 10
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: settingsBtn.hovered = true
            onExited: settingsBtn.hovered = false
            onClicked: root.openEthernetSettings()
          }
        }

        // Кнопка підключення/відключення
        Rectangle {
          id: wiredActionBtn
          property bool hovered: false
          implicitWidth: wiredActionLabel.implicitWidth + 12; height: 24; radius: 4
          color: root.wiredDevice?.connected ? (hovered ? Palette.hoverOverlay : Palette.bgLayer) : (hovered ? Palette.hoverOverlay : Palette.bgLayer)
          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            id: wiredActionLabel
            anchors.centerIn: parent
            text: root.wiredDevice?.connected ? "Disconnect" : "Connect"
            color: Palette.textLight
            font.family: Palette.font; font.pixelSize: 10
          }
          
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: wiredActionBtn.hovered = true
            onExited: wiredActionBtn.hovered = false
            onClicked: {
              if (root.wiredDevice && root.wiredDevice.name) {
                if (root.wiredDevice.connected) {
                  wiredProcess.command = ["nmcli", "device", "disconnect", root.wiredDevice.name];
                } else {
                  wiredProcess.command = ["nmcli", "device", "connect", root.wiredDevice.name];
                }
                wiredProcess.running = true;
              }
            }
          }
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Palette.accent
      opacity: 0.3
      visible: root.wiredDevice !== null && root.wifiDevice !== null && root.pendingNetwork === null
    }

    // --- Wi-Fi: заголовок та тумблер ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.wifiDevice !== null && root.pendingNetwork === null

      Text {
        text: "Wi-Fi"
        color: Palette.accent
        font.family: Palette.font; font.pixelSize: 16; font.bold: true
        Layout.fillWidth: true
      }

      // Тумблер увімкнення Wi-Fi
      Rectangle {
        id: wifiToggleBg
        property bool isHovered: false
        width: 36; height: 22; radius: 11
        color: root.wifiEnabled ? Palette.accent : Palette.bg2
        Behavior on color { ColorAnimation { duration: 150 } }
        border.width: isHovered ? 1 : 0
        border.color: Palette.hoverOverlay
        Behavior on border.width { NumberAnimation { duration: 120 } }

        Rectangle {
          x: root.wifiEnabled ? parent.width - width - 2 : 2
          width: 18; height: 18; radius: 9
          color: root.wifiEnabled ? Palette.bg1 : Palette.gray
          anchors.verticalCenter: parent.verticalCenter
          Behavior on x { NumberAnimation { duration: 150 } }
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: wifiToggleBg.isHovered = true
          onExited: wifiToggleBg.isHovered = false
          onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
        }
      }
    }

    // --- Діалог введення пароля ---
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.pendingNetwork !== null

      Text {
        text: "Connect to: " + (root.pendingNetwork?.name || "")
        color: Palette.accent
        font.family: Palette.font; font.pixelSize: 14; font.bold: true
      }

      // Поле пароля
      Rectangle {
        Layout.fillWidth: true
        height: 32
        radius: 6
        color: Palette.bgLayer
        border.width: 1
        border.color: Palette.accent

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.margins: 8
          color: Palette.textLight
          font.family: Palette.font; font.pixelSize: 12
          echoMode: TextInput.Password
          focus: true
          Component.onCompleted: forceActiveFocus()
        }
      }

      // Кнопки скасування / підключення
      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 8

        Rectangle {
          implicitWidth: 70; height: 24; radius: 4
          color: Palette.bgLayer
          Text { anchors.centerIn: parent; text: "Cancel"; color: Palette.mutedAlt; font.family: Palette.font; font.pixelSize: 11 }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.pendingNetwork = null;
              passwordInput.text = "";
            }
          }
        }

        Rectangle {
          implicitWidth: 70; height: 24; radius: 4
          color: Palette.accent
          Text { anchors.centerIn: parent; text: "Connect"; color: Palette.bgLayer; font.family: Palette.font; font.pixelSize: 11; font.bold: true }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.pendingNetwork && passwordInput.text.length > 0) {
                root.pendingNetwork.connectWithPsk(passwordInput.text);
              }
              root.pendingNetwork = null;
              passwordInput.text = "";
            }
          }
        }
      }
    }

    // Кнопка сканування мереж
    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      visible: root.wifiEnabled && root.wifiDevice !== null && root.pendingNetwork === null

      Text {
        text: "Available Networks"
        color: Palette.mutedAlt
        font.family: Palette.font; font.pixelSize: 12
        Layout.fillWidth: true
      }

      Rectangle {
        id: scanBtn
        property bool hovered: false
        implicitWidth: scanLabel.implicitWidth + 16; height: 24; radius: 4
        color: root.scanning ? Palette.sepBg : (hovered ? Palette.hoverOverlay : Palette.bgLayer)
        Behavior on color { ColorAnimation { duration: 150 } }

        // Пульсація під час сканування
        SequentialAnimation on opacity {
          running: root.scanning
          loops: Animation.Infinite
          NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }

        Text {
          id: scanLabel
          anchors.centerIn: parent
          text: root.scanning ? "Scanning..." : "Scan"
          color: Palette.textLight
          font.family: Palette.font; font.pixelSize: 11
        }
        
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: scanBtn.hovered = true
          onExited: scanBtn.hovered = false
          onClicked: {
            if (root.wifiDevice) {
              root.wifiDevice.scannerEnabled = !root.wifiDevice.scannerEnabled;
            }
          }
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Palette.accent
      opacity: 0.3
      visible: root.wifiEnabled && root.wifiDevice !== null && root.pendingNetwork === null
    }

    // --- Список Wi-Fi мереж ---
    ListView {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(contentHeight, 240)
      clip: true
      interactive: contentHeight > height
      visible: root.pendingNetwork === null

      model: ScriptModel {
        values: {
          if (!root.wifiDevice || !root.wifiEnabled || !root.wifiDevice.networks) return [];
          let list = root.wifiDevice.networks.values || [];
          // Сортування: підключена → збережена → за сигналом
          return list.filter(n => n !== null && n !== undefined).sort((a, b) => {
            if (a.connected && !b.connected) return -1;
            if (b.connected && !a.connected) return 1;
            if (a.known && !b.known) return -1;
            if (b.known && !a.known) return 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
          });
        }
      }

      delegate: Item {
        id: networkItem
        required property var modelData
        width: ListView.view.width
        height: 48

        RowLayout {
          anchors.fill: parent
          spacing: 6

          // Назва мережі + статус + сигнал
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: modelData.name || "Hidden Network"
              color: Palette.textLight
              font.family: Palette.font; font.pixelSize: 12
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            RowLayout {
              spacing: 6
              Text {
                text: modelData.connected ? "Connected" : (modelData.known ? "Saved" : (modelData.security ? "Secured" : "Open"))
                color: modelData.connected ? Palette.accent : Palette.mutedAlt
                font.family: Palette.font; font.pixelSize: 10
              }
              // Графічні bars сили сигналу замість тексту "Signal: N/4"
              RowLayout {
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                  model: 4

                  delegate: Rectangle {
                    required property int index
                    readonly property int activeBars: root.signalBars(networkItem.modelData.signalStrength)

                    width: 3
                    height: 4 + index * 3
                    radius: 1
                    color: index < activeBars ? Palette.accent : Palette.bg2
                    Layout.alignment: Qt.AlignBottom
                    Behavior on color { ColorAnimation { duration: 150 } }
                  }
                }
              }
            }
          }

          // Кнопка налаштувань (для збережених мереж)
          Rectangle {
            id: gearBtn
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: hovered ? Palette.hoverOverlay : Palette.bgLayer
            visible: modelData.known

            Text {
              anchors.centerIn: parent
              text: "\u2699"
              color: Palette.textLight
              font.family: Palette.font; font.pixelSize: 11
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: gearBtn.hovered = true
              onExited: gearBtn.hovered = false
              onClicked: root.openWifiSettings(modelData)
            }
          }

          // Кнопка видалення (для збережених, не підключених)
          Rectangle {
            id: forgetBtn
            property bool hovered: false
            width: 24; height: 24; radius: 4
            color: hovered ? Palette.hoverOverlay : Palette.bgLayer
            visible: modelData.known && !modelData.connected
            
            Text {
              anchors.centerIn: parent
              text: "\u2716"
              color: Palette.danger
              font.family: Palette.font; font.pixelSize: 10
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: forgetBtn.hovered = true
              onExited: forgetBtn.hovered = false
              onClicked: {
                if (typeof modelData.forget === "function") {
                  modelData.forget();
                }
              }
            }
          }

          // Кнопка підключення/відключення
          Rectangle {
            id: actionBtn
            property bool hovered: false
            implicitWidth: actionLabel.implicitWidth + 12; height: 24; radius: 4
            color: modelData.connected ? (hovered ? Palette.hoverOverlay : Palette.bgLayer) : (modelData.known ? (hovered ? Palette.widgetFg : Palette.accent) : (hovered ? Palette.hoverOverlay : Palette.bgLayer))
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              id: actionLabel
              anchors.centerIn: parent
              text: modelData.connected ? "Disconnect" : "Connect"
              color: modelData.known && !modelData.connected ? Palette.bgLayer : Palette.textLight
              font.family: Palette.font; font.pixelSize: 10
            }
            
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: actionBtn.hovered = true
              onExited: actionBtn.hovered = false
              onClicked: {
                if (modelData.connected) {
                  modelData.disconnect();
                } else if (!modelData.security) {
                  modelData.connect();
                } else {
                  root.pendingNetwork = modelData;
                }
              }
            }
          }
        }
      }
    }

    // Стан: мереж не знайдено
    Text {
      text: "No networks found"
      color: Palette.mutedAlt
      font.family: Palette.font; font.pixelSize: 12
      visible: root.wifiEnabled && root.wifiDevice !== null && root.pendingNetwork === null &&
               (!root.wifiDevice.networks || root.wifiDevice.networks.values.length === 0)
    }

    // Стан: адаптер недоступний
    Text {
      text: "Network adapter not available"
      color: Palette.danger
      font.family: Palette.font; font.pixelSize: 12
      visible: root.wifiDevice === null && root.wiredDevice === null
    }
  }
}
