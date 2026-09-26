// ============================================================
// quickshell/popups/KdeConnectPairingPopup.qml — підтвердження парування телефону (kcd)
// ============================================================
import Quickshell
import Quickshell.Io
import "../core"
import QtQuick
import QtQuick.Layouts

AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  // Сервіс kcd — прокидається через window.kdeConnect (Bar.qml)
  readonly property var svc: window ? window.kdeConnect : null
  readonly property var req: svc ? svc.pendingPairRequest : null

  implicitWidth: 360
  implicitHeight: contentCol.implicitHeight + 40
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  // Таймаут має збігатися з [pairing] timeout_secs у kcd.toml (30s)
  readonly property int timeoutSeconds: 30
  property int secondsLeft: timeoutSeconds
  centerScreen: window?.screen ?? Quickshell.screens[0]

  property string deviceName: req ? (req.deviceName || req.deviceId || "") : ""
  property string deviceId: req ? (req.deviceId || "") : ""

  // Process для accept/reject
  Process { id: pairAcceptProc; onExited: (code) => { running = false; if (svc) svc.refresh() } }
  Process { id: pairRejectProc; onExited: running = false }

  function decide(accepted) {
    if (!req) return
    countdown.stop()
    if (accepted) {
      // Прийняти: kcd pair <id> — як в терміналі `kcd pair <id>` коли телефон вже надіслав запит
      pairAcceptProc.command = ["kcd", "pair", deviceId]
      pairAcceptProc.running = true
    } else {
      // Відхилити: пробуємо kcd unpair best-effort (для ще не спареного
      // може не мати ефекту — тоді демон сам відхилить по timeout 30s),
      // попап закриваємо одразу щоб телефон не висів у очікуванні в UI
      if (deviceId !== "") {
        pairRejectProc.command = ["kcd", "unpair", deviceId]
        pairRejectProc.running = true
      }
      if (svc) svc.pendingPairRequest = null
    }
    close()
  }

  function openFor(req) {
    secondsLeft = timeoutSeconds
    countdown.restart()
    root.centerOnScreen()
    if (!visible) visible = true
  }

  // Синхронізація з сервісом
  function syncToRequest() {
    if (!req) {
      if (visible) close()
      return
    }
    // новий запит — відкрити
    openFor(req)
  }

  onReqChanged: syncToRequest()

  Component.onCompleted: {
    anchor.window = window
    syncToRequest()
  }

  Timer {
    id: countdown
    interval: 1000
    repeat: true
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
    spacing: 12

    Text {
      text: "Pair with " + (root.deviceName || "Phone") + "?"
      color: window.palette.textLight
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(14); font.bold: true
      elide: Text.ElideRight
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }
    Text {
      visible: !!root.deviceId
      text: root.deviceId.slice(0, 16) + (root.deviceId.length > 16 ? "…" : "")
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
      elide: Text.ElideRight
      Layout.fillWidth: true
    }
    Text {
      text: "The device wants to pair with this computer. Accept to allow battery, notifications, file sharing and clipboard sync."
      color: window.palette.muted
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    RowLayout {
      spacing: 8
      Layout.fillWidth: true
      Layout.topMargin: 8

      HoverButton {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 6
        palette: window.palette; appConfig: root.appConfig
        icon: "Reject"; iconSize: 12; fontBold: true
        normalBg: window.palette.bg1
        hoverBg: window.palette.danger
        normalFg: window.palette.textLight
        hoverFg: window.palette.bg0H
        borderWidth: 1; borderColor: window.palette.bg2
        cursorShape: Qt.PointingHandCursor
        onClicked: root.decide(false)
      }
      HoverButton {
        id: acceptBtn
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 6
        palette: window.palette; appConfig: root.appConfig
        icon: "Accept"; iconSize: 12; fontBold: true
        normalBg: window.palette.bg2
        hoverBg: window.palette.accent
        normalFg: window.palette.textLight
        hoverFg: window.palette.bg0H
        borderWidth: 1
        borderColor: acceptBtn.hovered ? window.palette.accent : window.palette.bg2
        cursorShape: Qt.PointingHandCursor
        onClicked: root.decide(true)
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 3
      radius: 1.5
      color: window.palette.bg2
      Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        radius: 1.5
        width: parent.width * root.secondsLeft / root.timeoutSeconds
        color: root.secondsLeft <= 5 ? window.palette.danger : window.palette.accent
        Behavior on width { NumberAnimation { duration: appConfig.anim(950); easing.type: Easing.Linear } }
      }
    }
  }
}
