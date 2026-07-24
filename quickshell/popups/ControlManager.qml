// ============================================================
// ControlManager.qml — центр керування: сповіщення, швидкі дії,
// кнопки живлення
// ============================================================
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../Palette.js" as Palette
import "../scripts/ControlState.js" as State

// Центр керування — сповіщення, швидкі перемикачі та кнопки живлення
AnimatedPopup {
  id: root
  bgOpacity: 0.70  // збережено індивідуальне значення, яке було локально в цьому попапі
  cornerRadius: 8  // теж було індивідуальним значенням цього попапу

  required property QtObject anchorItem
  required property QtObject window

  implicitWidth: 320
  implicitHeight: 460
  transformOrigin: Item.Top

  property var notificationsModel: null

  readonly property int unread: notificationsModel?.values?.length ?? 0
  readonly property var notifications: notificationsModel

  signal openWallpaperPopup()
  signal openBtManager()
  signal openNetManager()
  signal openSettingsPopup()

  // --- Brightness ---
  property int brightness: -1
  property int prevBrightness: 50
  property int _pendingBrightness: -1

  // --- Reading mode ---
  property int readingTemp: 6500
  // 3500 = max warmth, 6500 = off (≈identity)

  // Виконує дію живлення: shutdown, reboot, suspend, logout, lock
  function runPowerAction(action) {
    var cmd = []
    switch (action) {
      case "shutdown": cmd = ["/usr/bin/systemctl", "poweroff"]; break
      case "reboot":   cmd = ["/usr/bin/systemctl", "reboot"]; break
      case "suspend":  cmd = ["/usr/bin/systemctl", "suspend"]; break
      case "logout":   cmd = ["/usr/bin/hyprctl", "dispatch", "exit"]; break
      case "lock":     cmd = ["/usr/bin/hyprlock"]; break
    }
    powerProc.command = cmd
    powerProc.running = true
  }

  Process {
    id: powerProc
    onExited: running = false
  }

  // --- Brightness (ddcutil) ---
  function refreshBrightness() {
    getBrightnessProc.running = true
  }

  function setBrightness(val) {
    root.brightness = Math.max(0, Math.min(100, val))
    if (!setBrightnessProc.running) root._advanceSubStep()
    State.setBrightness(root.brightness)
    saveStateTimer.restart()
  }

  function toggleBrightness() {
    if (root.brightness <= 10) {
      root.setBrightness(root.prevBrightness)
    } else {
      root.prevBrightness = root.brightness
      root.setBrightness(10)
    }
  }

  function _advanceSubStep() {
    var target = root.brightness
    if (root._pendingBrightness < 0) {
      root._pendingBrightness = target
      root._doSetDdcutil(target)
      return
    }
    var diff = target - root._pendingBrightness
    if (Math.abs(diff) <= 15) {
      root._pendingBrightness = target
      root._doSetDdcutil(target)
    } else {
      root._pendingBrightness += diff > 0 ? 15 : -15
      root._doSetDdcutil(root._pendingBrightness)
    }
  }

  function _doSetDdcutil(val) {
    setBrightnessProc.command = ["ddcutil", "setvcp", "10", String(val)]
    setBrightnessProc.running = true
  }

  // --- Reading mode (hyprsunset) ---
  function setReadingTemp(val) {
    root.readingTemp = Math.max(3500, Math.min(6500, val))
    hyprsunsetDebounce.restart()
    State.setReadingTemp(root.readingTemp)
    saveStateTimer.restart()
  }

  function ensureHyprsunset() {
    hyprsunsetEnsureProc.command = ["sh", "-c",
      'SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock"; ' +
      'if echo "temperature 6500" | socat - UNIX-CONNECT:"$SOCK" 2>/dev/null; then exit 0; fi; ' +
      'killall hyprsunset 2>/dev/null; ' +
      'rm -f "$SOCK" 2>/dev/null; ' +
      'sleep 0.5; ' +
      'nohup hyprsunset --temperature 6500 >/dev/null 2>&1 &']
    hyprsunsetEnsureProc.running = true
  }

  function _doSetHyprsunset() {
    hyprsunsetRetry.stop()
    var temp = root.readingTemp
    hyprsunsetSocat.command = ["sh", "-c",
      'SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock"; ' +
      'if echo "temperature ' + temp + '" | socat - UNIX-CONNECT:"$SOCK" 2>/dev/null; then exit 0; fi; ' +
      'exit 1']
    hyprsunsetSocat.running = true
  }

  StdioCollector {
    id: brightnessCollector
    waitForEnd: true
    onDataChanged: {
      if (brightnessCollector.text) {
        var text = brightnessCollector.text.trim()
        var match = text.match(/current value = +(\d+).+max value = +(\d+)/)
        if (match) { root.brightness = parseInt(match[1]); root._pendingBrightness = root.brightness }
      }
    }
  }

  Process {
    id: getBrightnessProc
    command: ["ddcutil", "getvcp", "10"]
    stdout: brightnessCollector
  }

  Process {
    id: setBrightnessProc
    onExited: {
      running = false
      if (root._pendingBrightness !== root.brightness) root._advanceSubStep()
    }
  }

  Timer {
    id: brightnessPollTimer
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refreshBrightness()
  }

  Process {
    id: hyprsunsetEnsureProc
    onExited: running = false
  }

  // One-shot socat for temperature changes via socket
  Process {
    id: hyprsunsetSocat
    onExited: (exitCode) => {
      running = false
      if (exitCode !== 0 && root.readingTemp < 6500) hyprsunsetRetry.start()
    }
  }

  Timer {
    id: hyprsunsetDebounce
    interval: 80
    onTriggered: root._doSetHyprsunset()
  }

  Timer {
    id: hyprsunsetRetry
    interval: 500
    onTriggered: root._doSetHyprsunset()
  }

  // --- Persist state ---
  function saveState() {
    var escaped = State.serialize().replace(/'/g, "'\\''")
    saveStateProc.command = ["sh", "-c", "echo '" + escaped + "' > $HOME/.config/quickshell/control-state.json"]
    saveStateProc.running = true
  }

  StdioCollector {
    id: loadStateCollector
    waitForEnd: true
    onDataChanged: {
      if (loadStateCollector.text) {
        try { State.setData(JSON.parse(loadStateCollector.text)) } catch(e) { State.setData({}) }
        var savedBright = State.getBrightness()
        var savedTemp = State.getReadingTemp()
        if (savedBright >= 0) root.setBrightness(savedBright)
        if (savedTemp < 6500) root.setReadingTemp(savedTemp)
      }
    }
  }

  Process {
    id: loadStateProc
    command: ["sh", "-c", "cat $HOME/.config/quickshell/control-state.json"]
    stdout: loadStateCollector
  }

  Process {
    id: saveStateProc
    onExited: running = false
  }

  Timer {
    id: saveStateTimer
    interval: 500
    onTriggered: root.saveState()
  }

  // Закриває всі сповіщення
  function clearAll() {
    var model = root.notificationsModel
    if (!model) return
    var toDismiss = []
    var vals = model.values
    if (!vals) return
    for (var i = 0; i < vals.length; ++i) toDismiss.push(vals[i])
    for (var i = 0; i < toDismiss.length; ++i) if (toDismiss[i]) toDismiss[i].dismiss()
  }

  Component.onCompleted: { anchor.window = window; root.refreshBrightness(); root.ensureHyprsunset(); loadStateProc.running = true }

  onVisibleChanged: {
    if (visible) {
      var r = window.itemRect(anchorItem)
      anchor.rect = Qt.rect(r.x, r.y + r.height + 4, implicitWidth, implicitHeight)
      root.refreshBrightness()
      brightnessPollTimer.running = true
    } else {
      brightnessPollTimer.running = false
      hyprsunsetRetry.stop()
    }
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    // Ряд швидких дій: мережа, Bluetooth, шпалери
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      // Кнопка мережі
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: netArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "󰖩"
          color: netArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
        }

        MouseArea {
          id: netArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.openNetManager()
        }
      }

      // Кнопка Bluetooth
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: btArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: ""
          color: btArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
        }

        MouseArea {
          id: btArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.openBtManager()
        }
      }

      // Кнопка шпалер
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: wallArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "\uF03E"
          color: wallArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
        }

        MouseArea {
          id: wallArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.openWallpaperPopup()
        }
      }

      // Кнопка налаштувань
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: settingsArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: ""
          color: settingsArea.containsMouse ? Palette.green : Palette.gray
          Behavior on color { ColorAnimation { duration: 120 } }
          font.family: Palette.font; font.pixelSize: 13
        }

        MouseArea {
          id: settingsArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.openSettingsPopup()
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    // --- Brightness slider (ddcutil) ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: root.brightness >= 0

      Text {
        text: "\uF185"
        color: Palette.yellow
        font.family: Palette.font
        font.pixelSize: 14
        Layout.alignment: Qt.AlignVCenter
      }

      Item {
        Layout.fillWidth: true
        implicitHeight: 24

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          height: 6
          radius: 3
          color: Palette.bgAlpha

          Rectangle {
            width: parent.width * (Math.max(0, Math.min(root.brightness, 100)) / 100)
            height: parent.height
            radius: 3
            color: Palette.yellow
            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutSine } }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onPressed: mouse => { if (mouse.button === Qt.LeftButton) root.setBrightness(Math.round(mouse.x / width * 100)) }
          onPositionChanged: mouse => { if (pressedButtons & Qt.LeftButton) root.setBrightness(Math.round(mouse.x / width * 100)) }
          onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.toggleBrightness()
            else if (mouse.button === Qt.RightButton) root.setBrightness(100)
          }
          onWheel: wheel => {
            var step = wheel.angleDelta.y > 0 ? 5 : -5
            root.setBrightness(root.brightness + step)
          }
        }
      }

      Text {
        id: pctText
        text: root.brightness + "%"
        color: Palette.textLight
        font.family: Palette.font
        font.pixelSize: 11
        Layout.preferredWidth: 32
        horizontalAlignment: Text.AlignRight
        Layout.alignment: Qt.AlignVCenter
        Behavior on text {
          SequentialAnimation {
            NumberAnimation { target: pctText; property: "opacity"; to: 0.3; duration: 60 }
            NumberAnimation { target: pctText; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutSine }
          }
        }
      }
    }

    // --- Reading mode (hyprsunset) ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "\uF186"
        color: root.readingTemp < 6400 ? Palette.orange : Palette.gray
        font.family: Palette.font
        font.pixelSize: 14
        Layout.alignment: Qt.AlignVCenter
      }

      Item {
        Layout.fillWidth: true
        implicitHeight: 24

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          height: 6
          radius: 3
          color: Palette.bgAlpha

          Rectangle {
            readonly property real fill: Math.max(0, Math.min(1, (6500 - root.readingTemp) / 3000))
            width: parent.width * fill
            height: parent.height
            radius: 3
            color: Palette.orange
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onPressed: mouse => { if (mouse.button === Qt.LeftButton) root.setReadingTemp(6500 - Math.round(mouse.x / width * 3000)) }
          onPositionChanged: mouse => { if (pressedButtons & Qt.LeftButton) root.setReadingTemp(6500 - Math.round(mouse.x / width * 3000)) }
          onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.setReadingTemp(root.readingTemp < 6400 ? 6500 : 4500)
            else if (mouse.button === Qt.RightButton) root.setReadingTemp(6500)
          }
          onWheel: wheel => {
            var step = wheel.angleDelta.y > 0 ? -150 : 150
            root.setReadingTemp(root.readingTemp + step)
          }
        }
      }

      Text {
        text: root.readingTemp >= 6500 ? "OFF" : root.readingTemp + "K"
        color: root.readingTemp < 6400 ? Palette.orange : Palette.textLight
        font.family: Palette.font
        font.pixelSize: 11
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
        Layout.alignment: Qt.AlignVCenter
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    // Список сповіщень
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      ListView {
        id: notifList
        anchors.fill: parent
        visible: root.unread > 0
        spacing: 6
        interactive: contentHeight > height
        model: root.notifications

        delegate: Rectangle {
          required property var modelData
          readonly property var notif: modelData
          property bool hovered: false

          width: notifList.width
          height: delLayout.implicitHeight + 12
          radius: 6
          color: hovered ? Palette.bg2 : Palette.bg1
          Behavior on color { ColorAnimation { duration: 120 } }

          HoverHandler { onHoveredChanged: parent.hovered = hovered }

          // Акцентна смужка ліворуч
          Rectangle {
            width: 3
            height: parent.height - 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 2
            radius: 2
            color: Palette.yellow
          }

          RowLayout {
            id: delLayout
            x: 14; y: 6
            width: parent.width - 22
            spacing: 8



            // Назва додатка, заголовок, тіло сповіщення
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                text: notif.appName
                color: Palette.green
                font.family: Palette.font; font.pixelSize: 14; font.bold: true
              }

              Text {
                text: notif.summary
                color: Palette.fg
                font.family: Palette.font; font.pixelSize: 12; font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 1
                elide: Text.ElideRight
              }

              Text {
                text: notif.body
                color: Palette.gray
                font.family: Palette.font; font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: notif.body !== ""
              }
            }

            // Кнопка закриття сповіщення
            Rectangle {
              implicitWidth: 18; implicitHeight: 18; radius: 9
              color: closeArea.containsMouse ? Palette.red : Palette.bg1
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                anchors.centerIn: parent
                text: "\uF00D"
                color: closeArea.containsMouse ? Palette.bg0H : Palette.gray
                Behavior on color { ColorAnimation { duration: 120 } }
                font.family: Palette.font; font.pixelSize: 9
              }

              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notif.dismiss()
              }
            }
          }
        }
      }

      // Порожній стан — немає сповіщень
      ColumnLayout {
        anchors.centerIn: parent
        visible: root.unread === 0
        spacing: 4

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "\uF0F3"
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 22
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "No notifications"
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 12
        }
      }
    }

    // Кнопка "очистити все"
    RowLayout {
      id: clearAreaRow
      Layout.fillWidth: true
      visible: root.unread > 0

      Item { Layout.fillWidth: true }

      Rectangle {
        implicitWidth: 24; implicitHeight: 24; radius: 6
        color: clearArea.containsMouse ? Palette.bg2 : Palette.bg1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: "\uF12D"
          color: Palette.gray
          font.family: Palette.font; font.pixelSize: 11
        }

        MouseArea {
          id: clearArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.clearAll()
        }
      }
    }

    // Роздільник
    Rectangle {
      Layout.fillWidth: true
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Palette.bg2 }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    // Кнопки живлення (Lock, Suspend, Logout, Reboot, Shutdown)
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      property var actions: [
        { icon: "\uF023", tooltip: "Lock",     action: "lock",     accent: Palette.blue },
        { icon: "\uF186", tooltip: "Suspend",  action: "suspend",  accent: Palette.purple },
        { icon: "\uF2F5", tooltip: "Logout",   action: "logout",   accent: Palette.orange },
        { icon: "\uF021", tooltip: "Reboot",   action: "reboot",   accent: Palette.yellow },
        { icon: "\uF011", tooltip: "Shutdown", action: "shutdown", accent: Palette.red }
      ]

      Repeater {
        model: parent.actions

        delegate: Rectangle {
          required property var modelData
          readonly property var act: modelData
          property bool hovered: false

          Layout.fillWidth: true
          Layout.preferredWidth: 48
          implicitHeight: 36
          radius: 6
          color: hovered ? Palette.bg2 : Palette.bg1
          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            anchors.centerIn: parent
            text: act.icon
            color: Palette.fg
            font.family: Palette.font; font.pixelSize: 16
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: root.runPowerAction(act.action)
          }

          ToolTip.visible: containsMouseGlobal
          ToolTip.text: act.tooltip
          ToolTip.delay: 400
          property bool containsMouseGlobal: false
        }
      }
    }
  }
}
