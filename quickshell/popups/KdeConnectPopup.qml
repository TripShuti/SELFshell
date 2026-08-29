// ============================================================
// KdeConnectPopup.qml — попап телефону (kcd): батарея, ping/ring,
// share, сповіщення
// ============================================================
import Quickshell
import Quickshell.Io
import "../core"
import QtQuick
import QtQuick.Layouts

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

  // --- Дії: ping / ring / share ---
  Process { id: pingProc; onExited: running = false }
  Process { id: ringProc; onExited: running = false }
  Process {
    id: shareProc
    onExited: (code) => { running = false; if (code !== 0) console.warn("[kcd] share failed", code) }
  }
  Process {
    id: openShareProc
    onExited: running = false
  }
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
