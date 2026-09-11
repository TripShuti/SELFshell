// ============================================================
// quickshell/popups/ControlPopup.qml — центр керування: сповіщення, швидкі дії, кнопки живлення
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../scripts/ControlState.js" as State

// Центр керування — сповіщення, швидкі перемикачі та кнопки живлення
AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  // Менеджер бездіяльності (синглтон з shell.qml через Bar) — після кожного
  // збереження стану штовхаємо йому перечитування caffeine (вотчер вимкнено
  // через UAF Quickshell 0.3.0, див. IdleManager)
  required property QtObject idleManager
  palette: window.palette
  appConfig: window.appConfig

  implicitWidth: 320
  implicitHeight: layout.implicitHeight + 20
  transformOrigin: Item.Top

  property var notificationsModel: null

  readonly property int unread: notificationsModel?.values?.length ?? 0
  readonly property var notifications: notificationsModel

  // Сповіщення, згруповані по додатках: [{appName, icon, notifs: [...]}]
  property var groupedModel: []
  function rebuildGroups() {
    var vals = root.notifications?.values ?? []
    var map = {}
    for (var i = 0; i < vals.length; i++) {
      var n = vals[i]
      if (!n) continue
      var key = n.appName || "System"
      if (!map[key]) map[key] = []
      map[key].push(n)
    }
    var out = []
    for (var k in map) {
      out.push({ appName: k, icon: map[k][0].appIcon, notifs: map[k] })
    }
    root.groupedModel = out
  }
  onUnreadChanged: root.rebuildGroups()

  IconResolver { id: iconResolver }

  signal openWallpaperPopup()
  signal openBtManager()
  signal openNetManager()
  signal openSettingsPopup()
  signal screenshotTaken(string path)

  property bool muted: false

  // DND — повністю ховає сповіщення (джерело істини — config.json)
  readonly property bool dndEnabled: window.appConfig.cfg.dndEnabled

  // Caffeine mode: вимикає автоблокування/гаснення екрану/suspend по idle
  // (IdleManager підхоплює зміну через refreshCaffeine() після збереження)
  property bool caffeineEnabled: false

  // Виконує дію живлення: shutdown, reboot, suspend, logout, lock
  function runPowerAction(action) {
    var cmd = []
    switch (action) {
      case "shutdown": cmd = ["/usr/bin/systemctl", "poweroff"]; break
      case "reboot":   cmd = ["/usr/bin/systemctl", "reboot"]; break
      case "suspend":  cmd = ["sh", "-c", "qs ipc call lockscreen lock && /usr/bin/systemctl suspend"]; break
      // logout — Hyprland 0.56+: диспетчери через Lua (hl.dsp.exit),
      // старий синтаксис 'dispatch exit' більше не працює
      case "logout":   cmd = ["/usr/bin/hyprctl", "dispatch", "hl.dsp.exit()"]; break
      case "lock":     cmd = ["qs", "ipc", "call", "lockscreen", "lock"]; break
    }
    powerProc.command = cmd
    powerProc.running = true
  }

  Process {
    id: powerProc
    onExited: running = false
  }

  // --- Скріншоти ---
  // Кнопки викликають ті самі команди, що й гарячі клавіші в
  // hypr/modules/binds.lua, але через `hyprctl dispatch hl.dsp.exec_cmd(...)`:
  // grim/slurp запускає Hyprland у сесійному середовищі, тому оверлей slurp
  // завжди видно (запуск з QML Process давав невидимий layer-surface).
  // Результат шляху пише команда в data/last-shot.txt (маркер готовності),
  // FileView ловить зміну і показує тост через сигнал screenshotTaken.
  readonly property string _shotMarkerPath: {
    var url = Qt.resolvedUrl("../data/last-shot.txt").toString()
    return url.startsWith("file://") ? url.substring(7) : url
  }

  // Час останнього кліку по кожній кнопці скріншота (double-click guard).
  // Числові проперти замість var-об'єкта — щоб виключити будь-які
  // дива з мутацією об'єкта в property var.
  property int _lastShotTimeFull: 0
  property int _lastShotTimeRegion: 0

  // Подвійний клік МОЖЕ генерувати два onClicked (як у LauncherPopup) —
  // без debounce перший click стартує, але його тут же вбиває restart
  // (exit 15), і вибір області «не з'являється».
  function shotDebouncedClick(kind) {
    var now = (new Date()).getTime()
    var prev = kind === "full" ? root._lastShotTimeFull : root._lastShotTimeRegion
    if (now - prev < 350) return true
    if (kind === "full") root._lastShotTimeFull = now
    else root._lastShotTimeRegion = now
    return false
  }

  // Lua-аргумент для hyprctl dispatch — дослівно команда з binds.lua,
  // плюс прибирання порожнього файлу (скасування slurp) і маркер шляху.
  function shotCommand(kind) {
    var shell =
      'mkdir -p ~/Screenshots; f=~/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; ' +
      (kind === "region"
        ? 'geom="$(slurp)"; if [ -z "$geom" ]; then exit 0; fi; grim -g "$geom" - '
        : 'grim - ') +
      '| tee "$f" | wl-copy; if [ -s "$f" ]; then echo "$f" > "' + root._shotMarkerPath + '"; fi'
    return 'hl.dsp.exec_cmd("' + shell.replace(/"/g, '\\"') + '")'
  }

  function takeScreenshot(kind) {
    root.close()
    delayedShotTimer.shotKind = kind
    delayedShotTimer.start()
  }

  Timer {
    id: delayedShotTimer
    interval: 250
    repeat: false
    property string shotKind: ""
    onTriggered: {
      shotProc.command = ["/usr/bin/hyprctl", "dispatch", root.shotCommand(shotKind)]
      shotProc.running = true
    }
  }

  Process {
    id: shotProc
    onExited: running = false
  }

  // Маркер готовності: quickshell сам лише ЧИТАЄ/ЧИСТИТЬ файл,
  // пише його зовнішня команда скріншота (спільниый з IdleManager підхід)
  FileView {
    id: shotMarkerFile
    path: Qt.resolvedUrl("../data/last-shot.txt")
    watchChanges: true
    onFileChanged: this.reload()
    onDataChanged: {
      var p = shotMarkerFile.text().trim()
      if (!p) return
      shotMarkerFile.setText("")
      root.screenshotTaken(p)
    }
  }

  // Файл персистентності стану (яскравість, температура, muted)
  // — читається при старті, пишеться через 500ms після зміни
  FileView {
    id: stateFile
    path: Qt.resolvedUrl("../data/control-state.json")
    blockLoading: true
  }

  // --- Збереження стану ---
  function saveState() {
    stateFile.setText(State.serialize())
    // Caffeine застосовується одразу, не чекаючи вотчера (його нема — UAF)
    root.idleManager.refreshCaffeine()
  }

  function toggleMuted() {
    root.muted = !root.muted
    State.setMuted(root.muted)
    saveStateTimer.restart()
  }

  function toggleCaffeine() {
    root.caffeineEnabled = !root.caffeineEnabled
    State.setCaffeine(root.caffeineEnabled)
    saveStateTimer.restart()
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

  function loadSavedState() {
    var text = stateFile.text()
    if (!text) return
    try { State.setData(JSON.parse(text)) } catch(e) { State.setData({}) }
    var savedBright = State.getBrightness()
    var savedTemp = State.getReadingTemp()
    var savedMuted = State.getMuted()
    if (savedBright >= 0) brightSection.setBrightness(savedBright)
    if (savedTemp < 6500) tempSection.setReadingTemp(savedTemp)
    root.muted = savedMuted
    root.caffeineEnabled = State.getCaffeine()
  }

  popupWindow: window
  anchorTarget: anchorItem

  Component.onCompleted: { anchor.window = window; brightSection.refreshBrightness(); tempSection.ensureHyprsunset(); loadSavedState(); root.rebuildGroups() }

  onVisibleChanged: {
    if (visible) {
      // Стан process-wide (pragma library) — синхронізуємо кнопку зі змінами,
      // зробленими в попапі іншого монітора.
      root.caffeineEnabled = State.getCaffeine()
      root.positionUnderAnchor()
      brightSection.setPolling(true)
    } else {
      brightSection.setPolling(false)
      tempSection.stopRetry()
    }
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    // Ряд швидких дій: мережа, Bluetooth, шпалери
    QuickToggles {
      window: root
      onOpenNetManager: root.openNetManager()
      onOpenBtManager: root.openBtManager()
      onOpenWallpaperPopup: root.openWallpaperPopup()
      onOpenSettingsPopup: root.openSettingsPopup()
      onTakeShot: (kind) => {
        if (root.shotDebouncedClick(kind)) return
        root.takeScreenshot(kind)
      }
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // --- Повзунок яскравості (ddcutil) ---
    BrightnessSection {
      id: brightSection
      window: root
      onStateDirty: saveStateTimer.restart()
    }

    // --- Режим читання (hyprsunset) ---
    ReadingTempSection {
      id: tempSection
      window: root
      onStateDirty: saveStateTimer.restart()
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Список сповіщень, згрупованих по додатках
    NotificationList {
      window: root
      groupedModel: root.groupedModel
      unread: root.unread
    }

    // Кнопка "очистити все"
    RowLayout {
      id: clearAreaRow
      Layout.fillWidth: true
      Item { Layout.fillWidth: true }

      Rectangle {
        implicitWidth: 24; implicitHeight: 24; radius: 6
        color: clearArea.containsMouse ? window.palette.bg2 : window.palette.bg1
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

        Text {
          anchors.centerIn: parent
          text: "\uF12D"
          color: window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
        }

        MouseArea {
          id: clearArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.clearAll()
        }
      }

      Rectangle {
        implicitWidth: 24; implicitHeight: 24; radius: 6
        color: root.muted ? Qt.rgba(window.palette.red.r, window.palette.red.g, window.palette.red.b, 0.15)
             : (muteArea.containsMouse ? window.palette.bg2 : window.palette.bg1)
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

        Text {
          anchors.centerIn: parent
          text: root.muted ? "\uF026" : "\uF028"
          color: root.muted ? window.palette.red : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
          Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        }

        MouseArea {
          id: muteArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.toggleMuted()
        }
      }

      // Кнопка DND — повністю ховає сповіщення (тост, список, звук)
      Rectangle {
        implicitWidth: 24; implicitHeight: 24; radius: 6
        color: root.dndEnabled ? Qt.rgba(window.palette.red.r, window.palette.red.g, window.palette.red.b, 0.15)
             : (dndArea.containsMouse ? window.palette.bg2 : window.palette.bg1)
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

        Text {
          anchors.centerIn: parent
          text: root.dndEnabled ? "\uF1F6" : "\uF0F3"
          color: root.dndEnabled ? window.palette.red : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
          Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        }

        MouseArea {
          id: dndArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            window.appConfig.cfg.dndEnabled = !window.appConfig.cfg.dndEnabled
            window.appConfig.saveToFile()
          }
        }
      }

      // Кнопка caffeine mode — вимикає автоблокування/гаснення/suspend по idle
      Rectangle {
        implicitWidth: 24; implicitHeight: 24; radius: 6
        color: root.caffeineEnabled ? Qt.rgba(window.palette.green.r, window.palette.green.g, window.palette.green.b, 0.15)
             : (caffeineArea.containsMouse ? window.palette.bg2 : window.palette.bg1)
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

        Text {
          anchors.centerIn: parent
          text: "󰅶"
          color: root.caffeineEnabled ? window.palette.green : window.palette.gray
          font.family: window.palette.font; font.pixelSize: appConfig.scaled(11)
          Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
        }

        MouseArea {
          id: caffeineArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.toggleCaffeine()
        }

      }
    }

    // Роздільник
    GradientSeparator { midColor: window.palette.bg2 }

    // Кнопки живлення (Lock, Suspend, Logout, Reboot, Shutdown)
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      property var actions: [
        { icon: "\uF023", tooltip: "Lock",     action: "lock",     accent: window.palette.blue },
        { icon: "\uF186", tooltip: "Suspend",  action: "suspend",  accent: window.palette.purple },
        { icon: "\uF2F5", tooltip: "Logout",   action: "logout",   accent: window.palette.orange },
        { icon: "\uF021", tooltip: "Reboot",   action: "reboot",   accent: window.palette.yellow },
        { icon: "\uF011", tooltip: "Shutdown", action: "shutdown", accent: window.palette.red }
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
          color: hovered ? window.palette.bg2 : window.palette.bg1
          Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }

          Text {
            anchors.centerIn: parent
            text: act.icon
            color: window.palette.fg
            font.family: window.palette.font; font.pixelSize: appConfig.scaled(16)
            Behavior on color { ColorAnimation { duration: appConfig.anim(150) } }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: root.runPowerAction(act.action)
          }

        }
      }
    }
  }
}
