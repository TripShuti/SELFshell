// ============================================================
// quickshell/popups/NetworkPopup.qml — менеджер мереж: Wi-Fi, Ethernet, сканування
// ============================================================
import Quickshell
import Quickshell.Networking
import Quickshell.Io
import "../core"
import QtQuick
import QtQuick.Layouts

// Менеджер мереж — Wi-Fi та Ethernet з'єднання, сканування, налаштування
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

  property var pendingNetwork: null
  property var settingsNetwork: null
  property string settingsConnKind: "wifi"
  property string settingsDeviceName: ""
  property string statusMessage: ""
  property bool statusIsError: false
  // true, поки йде підключення з паролем — діалог залишається відкритим,
  // кнопка та поле блокується, застарілі результати процесу ігноруються
  property bool connecting: false

  NetworkConnectionSettingsPopup {
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

  // Повернення до мережевого менеджера при закритті налаштувань
  // (раніше NetworkPopup лишався прихованим — "чорна діра" після Escape/close)
  Connections {
    target: connectionSettings
    function onVisibleChanged() {
      if (!connectionSettings.visible && root.settingsNetwork !== null) {
        root.visible = true
        root.settingsNetwork = null
      }
    }
  }

  Process {
    id: wiredProcess
  }

  // Підключення до нової мережі з паролем.
  // Раніше використовувався quickshell connectWithPsk(), але NM створював
  // профіль з секретом agent-owned (psk-flags=1) — пароль не зберігався на
  // диск і втрачався після рестарту. nmcli dev wifi connect створює повноцінний
  // профіль з psk-flags=0 (пароль персистентний) і одразу активує з'єднання.
  Process {
    id: wifiConnectProcess
    onExited: (exitCode, exitStatus) => {
      // Ігноруємо застарілий результат: користувач міг скасувати/закрити попап
      // під час виконання nmcli
      if (!root.connecting) return;
      root.connecting = false;
      if (exitCode === 0) {
        root.statusMessage = "Connected";
        root.statusIsError = false;
        root.pendingNetwork = null;
        passwordInput.text = "";
      } else {
        // Діалог лишається відкритим з введеним паролем — легко виправити
        // помилку і повторити підключення
        root.statusMessage = "Connection failed (wrong password?)";
        root.statusIsError = true;
      }
    }
  }

  // Запускає підключення з паролем. Викликається і кнопкою Connect,
  // і клавішею Enter у полі пароля.
  function startConnect() {
    if (!pendingNetwork || connecting) return;
    // Мінімальна довжина WPA-PSK — 8 символів (як у NetworkConnectionSettingsPopup)
    if (passwordInput.text.length < 8) {
      statusMessage = "Password must be at least 8 characters";
      statusIsError = true;
      return;
    }
    connecting = true;
    statusMessage = "Connecting...";
    statusIsError = false;
    // Діалог лишається відкритим — результат з'явиться в onExited.
    // Пароль в argv: /proc/*/cmdline читається локальними процесами.
    // nmcli --ask тут не підходить — секрети він читає з /dev/tty, якого
    // в Process немає, і просто висне. Якщо колись захочемо сховати
    // пароль — шлях через тимчасовий keyfile + `nmcli con load`
    wifiConnectProcess.command = ["nmcli", "dev", "wifi", "connect", pendingNetwork.name, "password", passwordInput.text];
    wifiConnectProcess.running = true;
  }

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
        if (dev && (dev.type === DeviceType.Wired || (dev.name && (dev.name.startsWith("en") || dev.name.startsWith("eth"))))) {
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
      // guard на випадок відсутнього screen (як у BluetoothPopup)
      var sw = window.screen ? window.screen.width : 1920
      var sh = window.screen ? window.screen.height : 1080
      anchor.rect = Qt.rect(
        (sw - implicitWidth) / 2,
        (sh - implicitHeight) / 2,
        implicitWidth,
        implicitHeight
      )
      if (wifiDevice && wifiEnabled) wifiDevice.scannerEnabled = true;
    } else {
      if (wifiDevice) wifiDevice.scannerEnabled = false;
      pendingNetwork = null;
      connecting = false;
      statusMessage = "";
      statusIsError = false;
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
          color: window.palette.accent
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(16); font.bold: true
          Layout.fillWidth: true
        }
        
        Text {
          text: root.wiredDevice?.connected ? "Connected" : "Disconnected"
          color: root.wiredDevice?.connected ? window.palette.accent : window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(14)
        }
      }

      // Назва інтерфейсу + кнопки
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: root.wiredDevice?.name || "Wired Interface"
          color: window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(14)
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        // Кнопка налаштувань
        Rectangle {
          id: settingsBtn
          property bool hovered: false
          implicitWidth: settingsLabel.implicitWidth + 12; height: 24; radius: 4
          color: hovered ? window.palette.hoverOverlay : window.palette.bgLayer
          Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

          Text {
            id: settingsLabel
            anchors.centerIn: parent
            text: "Settings"
            color: window.palette.textLight
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
          color: hovered ? window.palette.hoverOverlay : window.palette.bgLayer
          Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

          Text {
            id: wiredActionLabel
            anchors.centerIn: parent
            text: root.wiredDevice?.connected ? "Disconnect" : "Connect"
            color: window.palette.textLight
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
      color: window.palette.accent
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
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(16); font.bold: true
        Layout.fillWidth: true
      }

      // Тумблер увімкнення Wi-Fi
      ToggleSwitch {
        checked: root.wifiEnabled
        palette: window.palette
        appConfig: window.appConfig
        Layout.alignment: Qt.AlignVCenter
        onToggled: function(value) { Networking.wifiEnabled = value }
      }
    }

    // --- Діалог введення пароля ---
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.pendingNetwork !== null

      // Фокус ставиться тоді, коли діалог СТАЄ видимим, а не при створенні —
      // forceActiveFocus на невидимому елементі не працює. Пароль очищаємо
      // лише при новому відкритті — при невдачі діалог не закривається і
      // введений пароль лишається для виправлення
      onVisibleChanged: {
        if (visible) {
          passwordInput.text = "";
          passwordInput.forceActiveFocus();
        }
      }

      Text {
        text: "Connect to: " + (root.pendingNetwork?.name || "")
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(14); font.bold: true
      }

      // Поле пароля
      Rectangle {
        Layout.fillWidth: true
        height: 32
        radius: 6
        color: window.palette.bgLayer
        border.width: 1
        border.color: window.palette.accent

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.margins: 8
          color: window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
          echoMode: TextInput.Password
          focus: true
          readOnly: root.connecting
          Keys.onReturnPressed: root.startConnect()
          Keys.onEnterPressed: root.startConnect()
        }
      }

      // Кнопки скасування / підключення
      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 8

        Rectangle {
          implicitWidth: 70; height: 24; radius: 4
          color: window.palette.bgLayer
          Text { anchors.centerIn: parent; text: "Cancel"; color: window.palette.mutedAlt; font.family: window.palette.font; font.pixelSize: appConfig.scaled(11) }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.connecting
            onClicked: {
              root.connecting = false;
              root.statusMessage = "";
              root.statusIsError = false;
              root.pendingNetwork = null;
              passwordInput.text = "";
            }
          }
        }

        Rectangle {
          implicitWidth: Math.max(70, connectLabel.implicitWidth + 12); height: 24; radius: 4
          color: window.palette.accent
          opacity: root.connecting ? 0.6 : 1
          Behavior on opacity { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
          Text { id: connectLabel; anchors.centerIn: parent; text: root.connecting ? "Connecting..." : "Connect"; color: window.palette.bgLayer; font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.connecting
            onClicked: root.startConnect()
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
        color: window.palette.mutedAlt
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
        Layout.fillWidth: true
      }

      Rectangle {
        id: scanBtn
        property bool hovered: false
        implicitWidth: scanLabel.implicitWidth + 16; height: 24; radius: 4
        color: root.scanning ? window.palette.sepBg : (hovered ? window.palette.hoverOverlay : window.palette.bgLayer)
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

        // Пульсація під час сканування
        SequentialAnimation on opacity {
          running: root.scanning
          loops: Animation.Infinite
          NumberAnimation { to: 0.5; duration: appConfig.anim(800); easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.0; duration: appConfig.anim(800); easing.type: Easing.InOutSine }
        }

        Text {
          id: scanLabel
          anchors.centerIn: parent
          text: root.scanning ? "Scanning..." : "Scan"
          color: window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
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
      color: window.palette.accent
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
              color: window.palette.textLight
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            RowLayout {
              spacing: 6
              Text {
                text: modelData.connected ? "Connected" : (modelData.known ? "Saved" : (modelData.security ? "Secured" : "Open"))
                color: modelData.connected ? window.palette.accent : window.palette.mutedAlt
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
                    color: index < activeBars ? window.palette.accent : window.palette.bg2
                    Layout.alignment: Qt.AlignBottom
                    Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
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
            color: hovered ? window.palette.hoverOverlay : window.palette.bgLayer
            visible: modelData.known

            Text {
              anchors.centerIn: parent
              text: "\u2699"
              color: window.palette.textLight
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
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
            color: hovered ? window.palette.hoverOverlay : window.palette.bgLayer
            visible: modelData.known && !modelData.connected
            
            Text {
              anchors.centerIn: parent
              text: "\u2716"
              color: window.palette.danger
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
            color: modelData.connected ? (hovered ? window.palette.hoverOverlay : window.palette.bgLayer) : (modelData.known ? (hovered ? window.palette.widgetFg : window.palette.accent) : (hovered ? window.palette.hoverOverlay : window.palette.bgLayer))
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

            Text {
              id: actionLabel
              anchors.centerIn: parent
              text: modelData.connected ? "Disconnect" : "Connect"
              color: modelData.known && !modelData.connected ? window.palette.bgLayer : window.palette.textLight
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
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
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
      visible: root.wifiEnabled && root.wifiDevice !== null && root.pendingNetwork === null &&
               (!root.wifiDevice.networks || root.wifiDevice.networks.values.length === 0)
    }

    // Стан: адаптер недоступний
    Text {
      text: "Network adapter not available"
      color: window.palette.danger
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
      visible: root.wifiDevice === null && root.wiredDevice === null
    }

    // Статус підключення/помилок
    Text {
      Layout.fillWidth: true
      visible: root.statusMessage.length > 0
      text: root.statusMessage
      color: root.statusIsError ? window.palette.danger : window.palette.accent
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
      wrapMode: Text.WordWrap
    }
  }
}
