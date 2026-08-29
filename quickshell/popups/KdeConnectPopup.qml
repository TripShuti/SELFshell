// ============================================================
// KdeConnectPopup.qml — попап телефону (kcd): батарея, ping/ring,
// share, сповіщення
// ============================================================
import Quickshell.Io
import "../core"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Попап телефону — батарея, ping/ring, share, список сповіщень
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

  readonly property var svc: window ? window.kdeConnect : null
  readonly property bool installed: svc ? svc.installed : false
  readonly property bool reachable: svc ? svc.isReachable : false
  readonly property int charge: svc ? svc.batteryCharge : -1
  readonly property bool charging: svc ? svc.batteryCharging : false
  readonly property string devName: svc ? svc.primaryDeviceName : ""
  readonly property string devId: svc ? svc.primaryDeviceId : ""

  property int screenW: window ? window.screen.width : 1920
  property int screenH: window ? window.screen.height : 1080
  property bool devicesExpanded: false

  Component.onCompleted: anchor.window = window

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
      if (svc) svc.refresh()
    }
  }

  // --- Дії: ping / ring / share / clipboard / sftp / devices ---
  Process { id: pingProc; onExited: running = false }
  Process { id: ringProc; onExited: running = false }
  Process { id: pairProc; stdout: StdioCollector { id: pairOut; waitForEnd: true; onStreamFinished: { var txt = String(pairOut.text ?? "").trim(); if (txt) pairStatus = txt.slice(0,300) } } onExited: (code) => { running = false; if (code !== 0 && pairStatus === "") pairStatus = "Pair failed (code " + code + ")" } }
  Process { id: unpairProc; onExited: (code) => { running = false; if (svc) svc.refresh() } }
  Process { id: connectProc; stdout: StdioCollector { id: connectOut; waitForEnd: true; onStreamFinished: { var txt = String(connectOut.text ?? "").trim(); if (txt) pairStatus = txt.slice(0,300) } } onExited: (code) => { running = false; if (svc) svc.refresh() } }
  Process {
    id: shareProc
    onExited: (code) => { running = false; if (code !== 0) console.warn("[kcd] share failed", code) }
  }
  Process {
    id: openShareProc
    onExited: running = false
  }
  Process { id: clipboardPushProc; onExited: (code) => { running = false; if (code !== 0) console.warn("[kcd] clipboard push failed", code) } }
  Process { id: sftpMountProc; onExited: running = false }
  Process { id: sftpUnmountProc; onExited: running = false }
  // Вибір файлу для share — через zenity/kdialog (FileDialog крашить quickshell)
  Process {
    id: sharePickerProc
    stdout: StdioCollector {
      id: pickerOut
      waitForEnd: true
      onStreamFinished: {
        var path = String(pickerOut.text ?? "").trim()
        if (!path) return
        // zenity може повернути | розділені шляхи — беремо перший
        if (path.includes("|")) path = path.split("|")[0]
        if (!path || !root.devId) return
        shareProc.command = ["kcd", "share", root.devId, path]
        shareProc.running = true
      }
    }
    onExited: (code) => { running = false }
  }

  function doPing() {
    if (!root.devId) return
    pingProc.command = ["kcd", "ping", root.devId]
    pingProc.running = true
  }
  function doRing() {
    if (!root.devId) return
    ringProc.command = ["kcd", "findmyphone", root.devId]
    ringProc.running = true
  }
  function doSharePick() {
    if (!root.devId) return
    // пробуємо zenity → kdialog → yad, тихо якщо нічого нема
    sharePickerProc.command = ["sh", "-c", "zenity --file-selection 2>/dev/null || kdialog --getopenfilename \"$HOME\" 2>/dev/null || yad --file-selection 2>/dev/null || true"]
    sharePickerProc.running = true
  }
  function doClipboardPush() {
    if (!root.devId) return
    clipboardPushProc.command = ["kcd", "clipboard", root.devId]
    clipboardPushProc.running = true
  }
  function doSftpMount() {
    if (!root.devId) return
    sftpMountProc.command = ["kcd", "sftp", "mount", root.devId]
    sftpMountProc.running = true
  }
  function doSftpUnmount() {
    if (!root.devId) return
    sftpUnmountProc.command = ["kcd", "sftp", "unmount", root.devId]
    sftpUnmountProc.running = true
  }
  function doSftpBrowse() {
    if (!root.devId) return
    sftpMountProc.command = ["kcd", "sftp", "browse", root.devId]
    sftpMountProc.running = true
  }
  property string pairStatus: ""
  property string connectIp: ""
  Timer { id: pairClearTimer; interval: 8000; repeat: false; onTriggered: root.pairStatus = "" }
  function doPair() {
    pairStatus = "Waiting for phone to accept..."
    pairClearTimer.restart()
    pairProc.command = ["kcd", "pair"]
    pairProc.running = true
  }
  function doPairDevice(id) {
    if (!id) return
    pairStatus = "Pairing " + id.slice(0,8) + "..."
    pairClearTimer.restart()
    pairProc.command = ["kcd", "pair", id]
    pairProc.running = true
  }
  function doUnpair(id) {
    if (!id) return
    unpairProc.command = ["kcd", "unpair", id]
    unpairProc.running = true
  }
  function doConnectIp() {
    var ip = connectIp.trim()
    if (!ip) return
    pairStatus = "Connecting to " + ip + "..."
    pairClearTimer.restart()
    connectProc.command = ["kcd", "connect", ip]
    connectProc.running = true
  }
  onPairStatusChanged: if (pairStatus !== "") pairClearTimer.restart()

  ColumnLayout {
    id: layout
    x: 8; y: 8
    width: parent.width - 16
    spacing: 8

    // Заголовок
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: "Phone"
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(16); font.bold: true
        Layout.fillWidth: true
      }
      Rectangle {
        visible: root.installed
        width: 8; height: 8; radius: 4
        color: root.reachable ? window.palette.green : window.palette.mutedAlt
        opacity: root.reachable ? 1 : 0.5
      }
      Text {
        visible: root.installed
        text: root.reachable ? "Connected" : "Offline"
        color: root.reachable ? window.palette.accent : window.palette.mutedAlt
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
      }
      // Mute toggle — іконка дзвінка з перекресленням
      Rectangle {
        visible: root.installed
        width: 24; height: 24; radius: 4
        color: muteArea.containsMouse ? window.palette.hoverOverlay : (window.appConfig.cfg.kcdMuted ? window.palette.bg2 : "transparent")
        border.width: window.appConfig.cfg.kcdMuted ? 1 : 0
        border.color: window.appConfig.cfg.kcdMuted ? window.palette.danger : "transparent"
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Text {
          anchors.centerIn: parent
          text: window.appConfig.cfg.kcdMuted ? "\uF1F6" : "\uF0F3"
          color: window.appConfig.cfg.kcdMuted ? window.palette.danger : (muteArea.containsMouse ? window.palette.green : window.palette.mutedAlt)
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
          Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        }
        MouseArea {
          id: muteArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            window.appConfig.cfg.kcdMuted = !window.appConfig.cfg.kcdMuted
            window.appConfig.saveToFile()
          }
        }
      }
    }


    // Статус kcd не встановлено
    Rectangle {
      visible: !root.installed
      Layout.fillWidth: true
      height: hintCol.implicitHeight + 16
      radius: 6
      color: window.palette.bg1
      border.width: 1; border.color: window.palette.bg2
      ColumnLayout {
        id: hintCol
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 4
        Text {
          text: "kcd not installed"
          color: window.palette.danger
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "yay -S kcd-bin  →  systemctl --user enable --now kcd"
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
        }
        Text {
          text: "Pair: kcd pair  (then accept on phone)"
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // Нема пристроїв
    Rectangle {
      visible: root.installed && !root.devId
      Layout.fillWidth: true
      height: noDevCol.implicitHeight + 16
      radius: 6
      color: window.palette.bg1
      border.width: 1; border.color: window.palette.bg2
      ColumnLayout {
        id: noDevCol
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 4
        Text {
          text: "No paired device"
          color: window.palette.fg
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Run: kcd pair  and accept on phone (same Wi-Fi)"
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    // --- Devices (kcd devices) — collapsible ---
    ColumnLayout {
      visible: root.installed
      Layout.fillWidth: true
      spacing: 4
      // Header — завжди видно, клік розгортає pairing/connect
      Rectangle {
        Layout.fillWidth: true
        height: 28
        radius: 6
        color: headerArea.containsMouse ? window.palette.hoverOverlay : "transparent"
        border.width: headerArea.containsMouse ? 1 : 0
        border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
        Behavior on border.width { NumberAnimation { duration: appConfig.anim(120) } }
        RowLayout {
          anchors.fill: parent
          anchors.margins: 6
          spacing: 6
          Text {
            text: "Devices (" + (svc ? svc.devices.length : 0) + ")"
            color: headerArea.containsMouse ? window.palette.green : window.palette.accent
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
            Layout.fillWidth: true
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
          }
          Text {
            text: root.devicesExpanded ? "▾" : "▸"
            color: headerArea.containsMouse ? window.palette.green : window.palette.mutedAlt
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(12)
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
            scale: headerArea.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: appConfig.anim(120); easing.type: Easing.OutBack } }
          }
        }
        MouseArea {
          id: headerArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.devicesExpanded = !root.devicesExpanded
        }
      }
      // Вміст — pairing/connect, список
      ColumnLayout {
        visible: root.devicesExpanded
        Layout.fillWidth: true
        spacing: 4
        // Mute row — дублює header іконку, але з явним ToggleSwitch
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: "Mute phone"
            color: window.palette.textLight
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
            Layout.fillWidth: true
          }
          ToggleSwitch {
            checked: window.appConfig.cfg.kcdMuted
            palette: window.palette
            appConfig: window.appConfig
            checkedColor: window.palette.danger
            onToggled: v => { window.appConfig.cfg.kcdMuted = v; window.appConfig.saveToFile() }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Rectangle {
            property bool hovered: false
            Layout.fillWidth: true; height: 24; radius: 6
            color: hovered ? window.palette.accent : window.palette.bg1
            border.width: 1; border.color: window.palette.bg2
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            Text { anchors.centerIn: parent; text: "Refresh"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(10) }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: if (svc) svc.refresh() }
          }
          Rectangle {
            property bool hovered: false
            Layout.fillWidth: true; height: 24; radius: 6
            color: hovered ? window.palette.accent : window.palette.bg1
            border.width: 1; border.color: window.palette.bg2
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            Text { anchors.centerIn: parent; text: "Pair"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(10) }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doPair() }
          }
        }
        // Список відомих пристроїв
        Repeater {
          model: svc ? svc.devices : []
          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            height: devRow.implicitHeight + 8
            radius: 6
            color: window.palette.bg1
            border.width: 1; border.color: (modelData.id === root.devId && root.reachable) ? window.palette.green : window.palette.bg2
            RowLayout {
              id: devRow
              anchors.centerIn: parent
              width: parent.width - 12
              spacing: 6
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: String(modelData.name ?? modelData.id ?? "").slice(0, 24)
                  color: window.palette.textLight
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  text: (modelData.connected ? "Connected" : (modelData.state ?? "PAIRED")) + " • " + String(modelData.id ?? "").slice(0,8)
                  color: modelData.connected ? window.palette.accent : window.palette.mutedAlt
                  font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
              // Pair (якщо не paired) / Unpair
              Rectangle {
                property bool hovered: false
                visible: !(modelData.state === "PAIRED" || modelData.paired)
                width: 48; height: 20; radius: 4
                color: hovered ? window.palette.accent : window.palette.bg2
                Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
                Text { anchors.centerIn: parent; text: "Pair"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(9) }
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doPairDevice(String(modelData.id ?? "")) }
              }
              Rectangle {
                property bool hovered: false
                width: 56; height: 20; radius: 4
                color: hovered ? window.palette.danger : window.palette.bg2
                Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
                Text { anchors.centerIn: parent; text: "Unpair"; color: window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(9) }
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doUnpair(String(modelData.id ?? "")) }
              }
            }
          }
        }
        // Connect by IP
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          TextField {
            id: ipField
            Layout.fillWidth: true
            placeholderText: "192.168.1.101"
            text: root.connectIp
            onTextChanged: root.connectIp = text
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
            color: window.palette.textLight
            placeholderTextColor: window.palette.mutedAlt
            background: Rectangle { color: window.palette.bg1; border.width: 1; border.color: window.palette.bg2; radius: 4 }
            padding: 6
          }
          Rectangle {
            property bool hovered: false
            width: 72; height: 24; radius: 6
            color: hovered ? window.palette.accent : window.palette.bg1
            border.width: 1; border.color: window.palette.bg2
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            Text { anchors.centerIn: parent; text: "Connect"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(10) }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doConnectIp() }
          }
        }
        Text {
          visible: pairStatus !== ""
          text: pairStatus
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          maximumLineCount: 3
          elide: Text.ElideRight
        }
      }
    }

    // Інфо про пристрій + батарея
    Rectangle {
      visible: root.installed && root.devId !== ""
      Layout.fillWidth: true
      height: battRow.implicitHeight + 16
      radius: 6
      color: window.palette.bg1
      border.width: 1; border.color: window.palette.bg2
      RowLayout {
        id: battRow
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 8
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            text: root.devName !== "" ? root.devName : root.devId
            color: window.palette.textLight
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: root.charge >= 0 ? (root.charge + "%" + (root.charging ? " ⚡ charging" : "")) : "Battery: --"
            color: root.charge >= 0 && root.charge <= 15 && !root.charging ? window.palette.danger : window.palette.mutedAlt
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
          }
        }
        // Прогрес-бар батареї
        Rectangle {
          visible: root.charge >= 0
          width: 80; height: 10; radius: 5
          color: window.palette.bg2
          Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.charge)) / 100
            height: parent.height; radius: parent.radius
            color: root.charging ? window.palette.green : (root.charge <= 15 ? window.palette.danger : window.palette.accent)
            Behavior on width { NumberAnimation { duration: appConfig.anim(300); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: appConfig.anim(220) } }
          }
        }
        Text {
          visible: root.charge >= 0
          text: root.charging ? "\uF0E7" : (root.charge <= 15 ? "\uF244" : root.charge <= 50 ? "\uF243" : root.charge <= 80 ? "\uF242" : "\uF240")
          color: root.charging ? window.palette.green : (root.charge <= 15 ? window.palette.danger : window.palette.fg)
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(16)
        }
      }
    }

    // Кнопки дій
    RowLayout {
      visible: root.installed && root.devId !== ""
      Layout.fillWidth: true
      spacing: 6
      // Ping
      Rectangle {
        property bool hovered: false
        Layout.fillWidth: true; height: 28; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text {
          anchors.centerIn: parent
          text: "\uF1EB Ping"
          color: parent.hovered ? window.palette.bg0H : window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.doPing()
        }
      }
      // Ring (find my phone)
      Rectangle {
        property bool hovered: false
        Layout.fillWidth: true; height: 28; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text {
          anchors.centerIn: parent
          text: "\uF028 Ring"
          color: parent.hovered ? window.palette.bg0H : window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.doRing()
        }
      }
      // Share
      Rectangle {
        property bool hovered: false
        Layout.fillWidth: true; height: 28; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text {
          anchors.centerIn: parent
          text: "\uF0EE Share"
          color: parent.hovered ? window.palette.bg0H : window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.doSharePick()
        }
      }
    }

    // Прогрес share
    Rectangle {
      visible: svc && svc.shareProgress !== null
      Layout.fillWidth: true
      height: 24; radius: 6
      color: window.palette.bg1
      border.width: 1; border.color: window.palette.accent
      RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6
        Text {
          text: svc && svc.shareProgress ? svc.shareProgress.file : ""
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Rectangle {
          width: 80; height: 6; radius: 3
          color: window.palette.bg2
          Rectangle {
            width: {
              if (!svc || !svc.shareProgress) return 0
              var t = svc.shareProgress.total
              if (t <= 0) return 0
              return parent.width * Math.min(1, svc.shareProgress.current / t)
            }
            height: parent.height; radius: parent.radius
            color: window.palette.green
          }
        }
      }
    }

    Text {
      visible: svc && svc.lastSharePath !== "" && svc.shareProgress === null
      text: "Saved: " + (svc ? svc.lastSharePath : "")
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      elide: Text.ElideRight
      Layout.fillWidth: true
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          openShareProc.command = ["xdg-open", svc.lastSharePath]
          openShareProc.running = true
        }
      }
    }

    // --- Clipboard ---
    RowLayout {
      visible: root.installed && root.devId !== ""
      Layout.fillWidth: true
      spacing: 6
      Text {
        text: "Clipboard"
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
        Layout.fillWidth: true
      }
      Rectangle {
        property bool hovered: false
        width: 90; height: 24; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text {
          anchors.centerIn: parent
          text: "Push"
          color: parent.hovered ? window.palette.bg0H : window.palette.textLight
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: root.doClipboardPush()
        }
      }
    }
    Text {
      visible: svc && svc.lastClipboard !== ""
      text: "Last from phone: " + svc.lastClipboard.slice(0, 60)
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    // --- SFTP (файли телефону) ---
    RowLayout {
      visible: root.installed && root.devId !== ""
      Layout.fillWidth: true
      spacing: 6
      Text {
        text: "Files"
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
        Layout.fillWidth: true
      }
      Rectangle {
        property bool hovered: false
        width: 56; height: 22; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text { anchors.centerIn: parent; text: "Browse"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(10) }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doSftpBrowse() }
      }
      Rectangle {
        property bool hovered: false
        width: 56; height: 22; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text { anchors.centerIn: parent; text: "Mount"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(10) }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doSftpMount() }
      }
      Rectangle {
        property bool hovered: false
        width: 64; height: 22; radius: 6
        color: hovered ? window.palette.accent : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        enabled: root.reachable
        opacity: root.reachable ? 1 : 0.5
        Text { anchors.centerIn: parent; text: "Unmount"; color: parent.hovered ? window.palette.bg0H : window.palette.textLight; font.family: window.palette.font; font.pixelSize: appConfig.scaled(10) }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.hovered = true; onExited: parent.hovered = false; onClicked: root.doSftpUnmount() }
      }
    }
    Text {
      visible: root.installed && root.devId !== "" && svc && (svc.sftpMountPoint !== "" || svc.sftpInfo !== "")
      text: {
        // sftpMountPoint з watch — це шлях на телефоні (/storage/...), локально монтується в ~/Downloads/kcd/mnt
        // Не хардкодимо /home/trip — показуємо ~/ для портативності (kcd mount_dir = ~/Downloads/kcd/mnt за замовч.)
        var localDisplay = "~/Downloads/kcd/mnt"
        // якщо svc.sftpMountPoint вже локальний (/tmp,/home,/run) — показуємо його, інакше показуємо локаль + телефон
        var remote = svc.sftpMountPoint
        if (remote.startsWith("/tmp") || remote.startsWith("/home") || remote.startsWith("/run")) return "Local: " + remote
        if (remote !== "" && svc.sftpInfo !== "") return "Local: " + localDisplay + " → Phone: " + remote
        if (remote !== "") return "Phone: " + remote + " → Local: " + localDisplay
        return svc.sftpInfo !== "" ? svc.sftpInfo : "Local: " + localDisplay
      }
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      elide: Text.ElideRight
      Layout.fillWidth: true
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { openShareProc.command = ["sh", "-c", "xdg-open \"$HOME/Downloads/kcd/mnt\""]; openShareProc.running = true }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: window.palette.accent
      opacity: 0.3
    }

    // Заголовок сповіщень
    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Text {
        text: "Notifications"
        color: window.palette.accent
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
        Layout.fillWidth: true
      }
      Text {
        text: svc ? String(svc.recentNotifications.length) : "0"
        color: window.palette.mutedAlt
        font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
      }
      Rectangle {
        property bool hovered: false
        width: 48; height: 20; radius: 4
        color: hovered ? window.palette.hoverOverlay : window.palette.bg1
        border.width: 1; border.color: window.palette.bg2
        visible: svc && svc.recentNotifications.length > 0
        Text {
          anchors.centerIn: parent
          text: "Clear"
          color: window.palette.mutedAlt
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.hovered = true
          onExited: parent.hovered = false
          onClicked: svc.recentNotifications = []
        }
      }
    }

    // Список сповіщень
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 4
      visible: svc && svc.recentNotifications.length > 0
      Repeater {
        model: svc ? svc.recentNotifications : []
        delegate: Rectangle {
          required property var modelData
          required property int index
          Layout.fillWidth: true
          height: notifCol.implicitHeight + 10
          radius: 6
          color: window.palette.bg1
          border.width: 1; border.color: window.palette.bg2
          ColumnLayout {
            id: notifCol
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 2
            Text {
              text: modelData.appName + (modelData.title ? " • " + modelData.title : "")
              color: window.palette.green
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(11); font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              visible: modelData.text !== ""
              text: modelData.text
              color: window.palette.mutedAlt
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
        }
      }
    }

    Text {
      visible: svc && svc.recentNotifications.length === 0
      text: "No notifications yet"
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
      Layout.alignment: Qt.AlignHCenter
    }

    // Підказка firewall
    Text {
      visible: root.installed && !root.reachable && root.devId !== ""
      text: "Phone offline — check same Wi-Fi / firewall 1716, 1739:1764"
      color: window.palette.mutedAlt
      font.family: window.palette.font; font.pixelSize: appConfig.scaled(10)
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
