// ============================================================
// popups/PairingPopup.qml — підтвердження Bluetooth-парингу:
// numeric comparison (код на обох екранах), введення PIN,
// дозвіл на паринг/сервіс. Дані приходять з core/PairingAgent.qml
// (qs-bt-agent пише запити в XDG_RUNTIME_DIR).
// ============================================================
import Quickshell
import Quickshell.Bluetooth
import "../core"
import QtQuick
import QtQuick.Layouts

AnimatedPopup {
  id: root

  required property QtObject window
  required property QtObject agent // core/PairingAgent

  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 360
  implicitHeight: contentCol.implicitHeight + 40
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  readonly property var req: agent ? agent.request : null
  readonly property bool actionable: req !== null && req.method !== "display" && req.method !== "displaypin"

  // Таймаут має збігатися з REQUEST_TIMEOUT_S у services/qs-bt-agent
  readonly property int timeoutSeconds: 55

  readonly property int screenW: window ? window.screen.width : 1920
  readonly property int screenH: window ? window.screen.height : 1080

  // Центрування на екрані — як у BluetoothPopup. Без цього popup-window
  // дефолтно липне у лівий верхній кут anchor-вікна
  function recenter() {
    anchor.edges = PopupAnchor.None
    anchor.gravity = PopupAnchor.None
    anchor.rect = Qt.rect(
      (screenW - implicitWidth) / 2,
      (screenH - implicitHeight) / 2,
      implicitWidth,
      implicitHeight
    )
  }

  property string btAddress: req ? (req.address || "") : ""
  property int secondsLeft: timeoutSeconds
  property string pinInput: ""
  property bool trustDevice: true

  property var btAdapter: Bluetooth.defaultAdapter

  // Останній показаний id: onReqChanged стреляє лише на ЗМІНУ значення,
  // тож початковий запит (що прийшов до завершення завантаження бару)
  // треба підхоплювати вручну в Component.onCompleted
  property int shownRequestId: -1

  function deviceName(address) {
    if (!btAdapter) return address
    var devices = [...btAdapter.devices.values]
    var dev = devices.find(d => d.address === address)
    return (dev && (dev.name || dev.deviceName)) || address
  }

  function serviceName(uuid) {
    if (!uuid) return "a service"
    var map = {
      "0000110b": "Audio",        "0000110d": "Advanced Audio",
      "0000111e": "Hands-free",   "00001112": "Headset",
      "00001105": "File transfer","0000110c": "Media control",
      "00001116": "Network access"
    }
    var key = uuid.substring(0, 8).toLowerCase()
    return map[key] || ("service " + key)
  }

  function rejectLabel() {
    return (root.req && (root.req.method === "pin" || root.req.method === "passkey")) ? "Cancel" : "Reject"
  }

  function acceptLabel() {
    return (root.req && (root.req.method === "pin" || root.req.method === "passkey")) ? "OK" : "Confirm"
  }

  function openFor(req) {
    shownRequestId = req.id
    secondsLeft = timeoutSeconds
    pinInput = ""
    trustDevice = true
    countdown.restart()
    recenter()
    if (!visible) visible = true
  }

  function decide(accepted) {
    if (!req) return
    countdown.stop()
    agent.respond(req.id, accepted, pinInput, trustDevice)
    close()
  }

  // Єдина точка синхронізації з агентом:
  //  - новий запит (включно з display/displaypin — вони показують код
  //    лише з кнопкою Close) — відкрити;
  //  - done/cancel або порожній req — закрити (повторний close після
  //    власного decide() безпечний — AnimatedPopup ігнорує його під час
  //    анімації виходу).
  function syncToRequest() {
    if (!req || req.method === "done" || req.method === "cancel") {
      if (visible) close()
      return
    }
    if (req.id !== shownRequestId) openFor(req)
  }

  onReqChanged: syncToRequest()

  Component.onCompleted: {
    anchor.window = window
    syncToRequest()
  }

  // Escape закриває попап лише візуально (обробник у AnimatedPopup):
  // запит усе одно відхилиться таймаутом агента через 55 c — свідомо
  // безпечніше, ніж випадковий Accept
  Timer {
    id: countdown
    interval: 1000
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      root.secondsLeft--
      if (root.secondsLeft <= 0) root.decide(false)
    }
  }

  ColumnLayout {
    id: contentCol
    x: 16
    y: 20
    width: parent.width - 32
    spacing: 10

    // --- Пристрій ---
    Text {
      text: root.deviceName(root.btAddress)
      color: window.palette.textLight
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(14); font.bold: true
      elide: Text.ElideRight
      Layout.fillWidth: true
    }
    Text {
      visible: !!root.btAddress
      text: root.btAddress
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
    }

    // --- Тіло за методом ---
    Text {
      readonly property bool isDisplay: root.req && (root.req.method === "display" || root.req.method === "displaypin")
      visible: root.req && root.req.passkey !== undefined
      text: isDisplay ? "Enter this code on the device:"
                      : "Confirm this passkey matches on both devices:"
      color: window.palette.muted
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
    }

    Text {
      visible: root.req && root.req.passkey !== undefined
      text: root.req ? root.req.passkey : ""
      color: window.palette.accent
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(30); font.bold: true
      font.letterSpacing: 6
      Layout.alignment: Qt.AlignHCenter
    }

    Text {
      visible: root.req && root.req.method === "authorize"
      text: "wants to pair with this computer."
      color: window.palette.muted
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Text {
      visible: root.req && root.req.method === "service"
      text: "requests access to " + root.serviceName(root.req ? root.req.uuid : "")
      color: window.palette.muted
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    // Введення PIN (legacy-пристрої, method=pin/passkey)
    RowLayout {
      visible: root.req && (root.req.method === "pin" || root.req.method === "passkey")
      spacing: 8
      Layout.fillWidth: true

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: window.palette.bg0H
        border.width: pinField.activeFocus ? 1 : 0
        border.color: window.palette.accent

        TextInput {
          id: pinField
          anchors.fill: parent
          anchors.margins: 8
          verticalAlignment: TextInput.AlignVCenter
          color: window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(13)
          clip: true
          focus: true
          onVisibleChanged: if (visible) forceActiveFocus()
          onTextChanged: root.pinInput = text
          onAccepted: if (root.pinInput.length > 0) root.decide(true)
        }
      }

      Text {
        text: "PIN/passkey"
        color: window.palette.mutedAlt
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
      }
    }

    // --- Довіра пристрою (після успішного парингу сервіси підключаються
    // без повторних запитів) ---
    RowLayout {
      visible: root.actionable
      spacing: 8
      Layout.fillWidth: true

      Text {
        text: "Trust this device"
        color: window.palette.muted
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
        Layout.fillWidth: true
      }

      ToggleSwitch {
        checked: root.trustDevice
        palette: window.palette
        appConfig: window.appConfig
        checkedColor: window.palette.widgetFg
        trackWidth: 28; trackHeight: 16; knobSize: 12
        Layout.alignment: Qt.AlignVCenter
        onToggled: value => { root.trustDevice = value }
      }
    }

    // --- Кнопки ---
    RowLayout {
      spacing: 8
      Layout.fillWidth: true
      Layout.topMargin: 4

      Repeater {
        model: root.actionable
          ? [{ label: root.rejectLabel(), danger: true, act: false },
             { label: root.acceptLabel(), danger: false, act: true }]
          : [{ label: "Close", danger: true, act: null }]

        delegate: Rectangle {
          required property var modelData
          property bool hovered: false

          Layout.fillWidth: true
          implicitHeight: 30
          radius: 5
          color: modelData.danger
            ? (hovered ? window.palette.danger : window.palette.bgLayer)
            : (hovered ? window.palette.widgetFg : window.palette.bgLayer)
          Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

          Text {
            anchors.centerIn: parent
            text: modelData.label
            color: modelData.danger
              ? (parent.hovered ? window.palette.bg0H : window.palette.danger)
              : (parent.hovered ? window.palette.bg0H : window.palette.textLight)
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: {
              if (modelData.act === null) { root.close(); return }
              root.decide(modelData.act)
            }
          }
        }
      }
    }

    // --- Прогрес-бар таймауту ---
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 3
      radius: 1.5
      color: window.palette.bg2
      visible: root.actionable

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: 1.5
        width: parent.width * root.secondsLeft / root.timeoutSeconds
        color: root.secondsLeft <= 10 ? window.palette.danger : window.palette.accent
        Behavior on width { NumberAnimation { duration: appConfig.anim(950); easing.type: Easing.Linear } }
      }
    }
  }
}
