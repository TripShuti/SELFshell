// ============================================================
// Bar.qml — головна панель системи (top bar) з віджетами,
// попапами та моніторами
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "Palette.js" as Palette
import QtQuick
import QtQuick.Layouts
import "widgets"
import "popups"
import "monitors"

// --- Сама панель ---
PanelWindow {
  id: root

  required property var modelData
  screen: modelData

  readonly property real pillHeight: root.implicitHeight - 8

  // Активні (реально завантажені зараз) інстанси віджетів — заповнюється
  // Loader-ами всередині пігулок через registerActive(). Перепризначення
  // ЦІЛОГО об'єкта (не мутація ключа) потрібне, щоб QML-біндинги, які
  // читають ці властивості (Connections/anchorItem нижче), реагували на
  // зміну.
  property var activeWidgets: ({})
  function registerActive(name, item) {
    var copy = Object.assign({}, activeWidgets)
    copy[name] = item
    activeWidgets = copy
  }

  readonly property Item launcherWidget: activeWidgets["launcher"] ?? null
  readonly property Item clockWidget: activeWidgets["clock"] ?? null
  readonly property Item mprisWidget: activeWidgets["mpris"] ?? null
  readonly property Item genshinWidget: activeWidgets["genshin"] ?? null
  readonly property Item audioWidget: activeWidgets["audio"] ?? null
  readonly property Item controlWidget: activeWidgets["control"] ?? null
  readonly property Item btWidget: activeWidgets["bt"] ?? null
  readonly property Item netWidget: activeWidgets["net"] ?? null
  readonly property Item trayWidget: activeWidgets["tray"] ?? null

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 36
  color: "transparent"
  exclusiveZone: 36

  // --- Спільний стан конфігурації (shared instance) ---
  component AppConfig: QtObject {
    property bool launcherEnabled: true
    property bool workspacesEnabled: true
    property bool mprisEnabled: true
    property bool clockEnabled: true
    property bool timerEnabled: true
    property bool genshinEnabled: true
    property bool keyboardEnabled: true
    property bool audioEnabled: true
    property bool controlEnabled: true
    property bool btEnabled: true
    property bool netEnabled: true
    property bool trayEnabled: true


    // Фіксований канонічний список усіх віджетів — використовується
    // Settings-попапом для стабільного порядку рядків (не залежить від
    // того, в якій пігулці зараз лежить віджет).
    readonly property var allWidgetNames: [
      "launcher", "workspaces", "mpris", "clock", "timer",
      "genshin", "keyboard", "audio", "control", "bt", "net", "tray"
    ]

    // Порядок ВСЕРЕДИНІ пігулки + приналежність до пігулки визначаються
    // належністю імені до одного з цих трьох масивів. Окремої властивості
    // "xPill" більше не потрібно — пігулка це і є масив, де лежить ім'я.
    property var leftOrder: ["launcher", "workspaces", "mpris"]
    property var centerOrder: ["clock", "timer", "genshin"]
    property var rightOrder: ["tray", "sep-0", "bt", "net", "sep-1", "keyboard", "audio", "control"]

    function isSep(name) {
      return name === "sep" || String(name).startsWith("sep-")
    }

    function addSep(pillName) {
      var maxId = -1
      var all = [leftOrder, centerOrder, rightOrder]
      for (var a = 0; a < all.length; a++) {
        for (var i = 0; i < all[a].length; i++) {
          var m = String(all[a][i]).match(/^sep-(\d+)$/)
          if (m) maxId = Math.max(maxId, parseInt(m[1]))
        }
      }
      var name = "sep-" + (maxId + 1)
      var arr = pillOrderFor(pillName).slice()
      arr.push(name)
      if (pillName === "left") leftOrder = arr
      else if (pillName === "center") centerOrder = arr
      else rightOrder = arr
    }

    function pillOrderFor(pillName) {
      return pillName === "left" ? leftOrder : pillName === "center" ? centerOrder : rightOrder
    }

    function pillOf(name) {
      if (leftOrder.indexOf(name) !== -1) return "left"
      if (centerOrder.indexOf(name) !== -1) return "center"
      if (rightOrder.indexOf(name) !== -1) return "right"
      return "left"
    }

    // Переносить віджет в іншу пігулку (додається в кінець її списку)
    function moveToPill(name, targetPill) {
      leftOrder = leftOrder.filter(n => n !== name)
      centerOrder = centerOrder.filter(n => n !== name)
      rightOrder = rightOrder.filter(n => n !== name)
      if (targetPill === "left") leftOrder = leftOrder.concat([name])
      else if (targetPill === "center") centerOrder = centerOrder.concat([name])
      else rightOrder = rightOrder.concat([name])
    }

function moveToPillAt(name, targetPill, targetIndex) {
  leftOrder = leftOrder.filter(n => n !== name)
  centerOrder = centerOrder.filter(n => n !== name)
  rightOrder = rightOrder.filter(n => n !== name)
  var arr = pillOrderFor(targetPill).slice()
  var idx = Math.max(0, Math.min(targetIndex, arr.length))
  arr.splice(idx, 0, name)
  if (targetPill === "left") leftOrder = arr
  else if (targetPill === "center") centerOrder = arr
  else rightOrder = arr
}

    function cyclePill(name) {
      var pills = ["left", "center", "right"]
      var idx = pills.indexOf(pillOf(name))
      moveToPill(name, pills[(idx + 1) % 3])
    }

    // Пересуває віджет на 1 позицію вгору(-1)/вниз(+1) всередині ЙОГО
    // поточної пігулки. Межі списку — no-op (нікуди рухати).
    function moveWithinPill(name, direction) {
      var p = pillOf(name)
      var arr = pillOrderFor(p).slice()
      var idx = arr.indexOf(name)
      if (idx === -1) return
      var newIdx = idx + direction
      if (newIdx < 0 || newIdx >= arr.length) return
      var tmp = arr[idx]; arr[idx] = arr[newIdx]; arr[newIdx] = tmp
      if (p === "left") leftOrder = arr
      else if (p === "center") centerOrder = arr
      else rightOrder = arr
    }

    function loadFromString(str) {
      function gv(name, fallback) {
        var m = str.match(new RegExp('var\\s+' + name + '\\s*=\\s*(true|false);'))
        return m ? m[1] === "true" : fallback
      }
      function ga(name, fallback) {
        var m = str.match(new RegExp('var\\s+' + name + '\\s*=\\s*(\\[[^\\]]*\\]);'))
        try { return m ? JSON.parse(m[1]) : fallback } catch (e) { return fallback }
      }
      try {
        launcherEnabled   = gv("launcherEnabled", true)
        workspacesEnabled = gv("workspacesEnabled", true)
        mprisEnabled      = gv("mprisEnabled", true)
        clockEnabled      = gv("clockEnabled", true)
        timerEnabled      = gv("timerEnabled", true)
        genshinEnabled    = gv("genshinEnabled", true)
        keyboardEnabled   = gv("keyboardEnabled", true)
        audioEnabled      = gv("audioEnabled", true)
        controlEnabled    = gv("controlEnabled", true)
        btEnabled         = gv("btEnabled", true)
        netEnabled        = gv("netEnabled", true)
        trayEnabled       = gv("trayEnabled", true)
        leftOrder   = ga("leftOrder",   ["launcher", "workspaces", "mpris"])
        centerOrder = ga("centerOrder", ["clock", "timer", "genshin"])
        rightOrder  = ga("rightOrder",  ["tray", "sep-0", "bt", "net", "sep-1", "keyboard", "audio", "control"])
      } catch (e) { console.warn("AppConfig.load: ", e) }
    }

    function saveString() {
      var w = (n, e) => 'var ' + n + 'Enabled = ' + e + ';'
      return ".pragma library\n"
        + w("launcher",   launcherEnabled)   + "\n"
        + w("workspaces", workspacesEnabled) + "\n"
        + w("mpris",      mprisEnabled)      + "\n"
        + w("clock",      clockEnabled)      + "\n"
        + w("timer",      timerEnabled)      + "\n"
        + w("genshin",    genshinEnabled)    + "\n"
        + w("keyboard",   keyboardEnabled)   + "\n"
        + w("audio",      audioEnabled)      + "\n"
        + w("control",    controlEnabled)    + "\n"
        + w("bt",         btEnabled)         + "\n"
        + w("net",        netEnabled)        + "\n"
        + w("tray",       trayEnabled)       + "\n"
        + "var leftOrder = "   + JSON.stringify(leftOrder)   + ";\n"
        + "var centerOrder = " + JSON.stringify(centerOrder) + ";\n"
        + "var rightOrder = "  + JSON.stringify(rightOrder)  + ";\n"
    }

    function saveToFile() {
      var text = saveString().replace(/'/g, "'\\''")
      saveProc.command = ["sh", "-c", "echo '" + text + "' > $HOME/.config/quickshell/Config.js"]
      saveProc.running = true
    }
  }

  readonly property AppConfig appConfig: AppConfig {}

  Process { id: saveProc; onExited: running = false }

  property string loadBuffer: ""

  Process {
    id: loadProcess
    command: ["sh", "-c", "cat $HOME/.config/quickshell/Config.js"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: (data) => { root.loadBuffer += data + "\n" }
    }
    onExited: {
      if (root.loadBuffer.trim()) appConfig.loadFromString(root.loadBuffer.trim())
      root.loadBuffer = ""
      running = false
    }
  }

  Component.onCompleted: {
    loadProcess.running = true
  }

  // Пігулка — контейнер з градієнтом для групи віджетів
  component Pill: Item {
    id: pillRoot
    property alias pillColor: pillBg.color
    property alias radius: pillBg.radius
    default property alias data: pillBg.data
    property real glowStrength: 0.16

    // Зовнішнє сяйво навколо пігулки
    Rectangle {
      anchors.fill: pillBg
      anchors.margins: -2
      radius: pillBg.radius + 2
      color: "transparent"
      border.width: 1
      border.color: Palette.hoverBg
      opacity: 0.1
    }

    // Тіло пігулки з градієнтом
    Rectangle {
      id: pillBg
      anchors.fill: parent
      clip: true
      color: Palette.bgAlpha
      opacity: 1
      border.width: 0
      border.color: Palette.outlineVariant

      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(Palette.baseOverlay, 1.18) }
        GradientStop { position: 1.0; color: Palette.bgAlpha }
      }

      Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
  }

  // --- Шаблони компонентів для динамічного рендеру пігулок ---
  // Loader.sourceComponent бере звідси потрібний тип за іменем віджета.
  // Layout.fillHeight/alignment ставляться на сам Loader (в делегаті
  // Repeater-а нижче), а не тут — бо прямий Layout-нащадок RowLayout це
  // Loader, а не завантажений ним item. Для тих двох, кому реально
  // потрібен fillHeight (Mpris/Audio), сам item заповнює Loader через
  // anchors.fill: parent.
  Component { id: launcherComp;   LauncherWidget { anchors.fill: parent } }
  Component { id: workspacesComp; Workspaces { } }
  Component { id: mprisComp;      MprisWidget { anchors.fill: parent; cavBars: cavaMonitor.bars } }
  Component { id: clockComp;      ClockWidget { } }
  Component { id: timerComp;      TimerWidget { anchors.fill: parent } }
  Component { id: genshinComp;    GenshinWidget { anchors.fill: parent; resinText: genshinMonitor.resinText; resinClass: genshinMonitor.resinClass } }
  Component { id: keyboardComp;   KeyboardLayout { anchors.fill: parent } }
  Component { id: audioComp;      Audio { anchors.fill: parent } }
  Component { id: controlComp;    ControlWidget { anchors.fill: parent; unread: controlPopup.unread } }
  Component { id: btComp;         BluetoothWidget { anchors.fill: parent } }
  Component { id: netComp;        NetWidget { anchors.fill: parent } }
  Component { id: trayComp;       TrayWidget { anchors.fill: parent } }

  readonly property var widgetComponents: ({
    launcher: launcherComp, workspaces: workspacesComp, mpris: mprisComp,
    clock: clockComp, timer: timerComp, genshin: genshinComp,
    keyboard: keyboardComp, audio: audioComp, control: controlComp,
    bt: btComp, net: netComp, tray: trayComp
  })

  // Ці віджети самі всередині читають implicitHeight: parent?.height,
  // тому Loader-у, що їх завантажує, потрібна РЕАЛЬНА висота від
  // RowLayout (fillHeight), інакше він сам візьме висоту з item-а, а той —
  // з Loader-а, замкнене коло, що резолвиться в 0 (0×0 MouseArea = не
  // клікається, і жодного варнінгу при цьому не буде).
  function widgetNeedsFillHeight(name) {
    return name === "mpris" || name === "audio"
        || name === "launcher" || name === "control"
        || name === "genshin" || name === "timer"
        || name === "bt" || name === "net" || name === "tray"
        || name === "keyboard"
  }

  // Ліва пігулка
  Pill {
    id: leftPill
    anchors {
      left: parent.left
      leftMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: pillHeight
    radius: pillHeight / 8
    width: leftRow.implicitWidth + 16

    RowLayout {
      id: leftRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Repeater {
        id: leftRepeater
        model: root.appConfig.leftOrder.filter(name => root.appConfig.isSep(name) || root.appConfig[name + "Enabled"])
        delegate: RowLayout {
          required property string modelData
          spacing: 4

          Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: root.widgetNeedsFillHeight(modelData)
            sourceComponent: root.widgetComponents[modelData]
            onLoaded: root.registerActive(modelData, item)
            visible: !root.appConfig.isSep(modelData)
          }
          Separator {
            Layout.alignment: Qt.AlignVCenter
            visible: root.appConfig.isSep(modelData)
          }
        }
      }
    }
  }

  // Центральна пігулка
  Pill {
    id: centerPill
    anchors.centerIn: parent
    height: pillHeight
    radius: pillHeight / 8
    width: centerRow.implicitWidth + 16
    glowStrength: (root.genshinWidget && root.genshinWidget.resinClass === "critical") ? 0.32 : 0.16
    Behavior on glowStrength { NumberAnimation { duration: 220 } }

    RowLayout {
      id: centerRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Repeater {
        id: centerRepeater
        model: root.appConfig.centerOrder.filter(name => root.appConfig.isSep(name) || root.appConfig[name + "Enabled"])
        delegate: RowLayout {
          required property string modelData
          spacing: 4

          Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: root.widgetNeedsFillHeight(modelData)
            sourceComponent: root.widgetComponents[modelData]
            onLoaded: root.registerActive(modelData, item)
            visible: !root.appConfig.isSep(modelData)
          }
          Separator {
            Layout.alignment: Qt.AlignVCenter
            visible: root.appConfig.isSep(modelData)
          }
        }
      }
    }
  }

  // Права пігулка
  Pill {
    id: rightPill
    anchors {
      right: parent.right
      rightMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: pillHeight
    radius: pillHeight / 8
    width: rightRow.implicitWidth + 16

    RowLayout {
      id: rightRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Repeater {
        id: rightRepeater
        model: root.appConfig.rightOrder.filter(name => root.appConfig.isSep(name) || root.appConfig[name + "Enabled"])
        delegate: RowLayout {
          required property string modelData
          spacing: 4

          Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: root.widgetNeedsFillHeight(modelData)
            sourceComponent: root.widgetComponents[modelData]
            onLoaded: root.registerActive(modelData, item)
            visible: !root.appConfig.isSep(modelData)
          }
          Separator {
            Layout.alignment: Qt.AlignVCenter
            visible: root.appConfig.isSep(modelData)
          }
        }
      }
    }
  }

  // Календар
  CalendarPopup {
    id: calendarPopup
    window: root
    anchorItem: root.clockWidget
    visible: false
  }

  // Мікшер аудіо
  AudioMixerPopup {
    id: audioPopup
    window: root
    anchorItem: root.audioWidget
    visible: false
  }

  // Керування Bluetooth
  BtManager {
    id: btPopup
    window: root
    visible: false
  }

  // Керування мережами
  NetManager {
    id: netPopup
    window: root
    visible: false
  }

  // Сервер сповіщень — ловить системні сповіщення
  NotificationServer {
    id: notifServer
    actionsSupported: true
    bodySupported: true

    onNotification: (notif) => {
      notif.tracked = true
      notifToast.showNotif(notif)
    }
  }

  // Монітор аудіо-візуалізації (cava)
  CavaMonitor {
    id: cavaMonitor
    appConfig: root.appConfig
  }

  // Монітор Genshin Impact
  GenshinMonitor {
    id: genshinMonitor
    appConfig: root.appConfig
  }

  // Попап медіаплеєра
  MprisPopup {
    id: mprisPopup
    window: root
    anchorItem: root.mprisWidget
    visible: false
    cavBars: cavaMonitor.bars
  }

  // Попап Genshin
  GenshinPopup {
    id: genshinPopup
    window: root
    anchorItem: root.genshinWidget
    visible: false
    resinText: genshinMonitor.resinText
    resinClass: genshinMonitor.resinClass
    details: genshinMonitor.tooltip
    refreshStatus: genshinMonitor.refreshStatus
    refreshMessage: genshinMonitor.refreshMessage
  }

  // Центр керування (сповіщення, швидкі дії)
  ControlManager {
    id: controlPopup
    window: root
    anchorItem: root.controlWidget
    visible: false
    notificationsModel: notifServer.trackedNotifications
  }

  // Вибір шпалер
  WallpaperPopup {
    id: wallpaperPopup
    window: root
    visible: false
  }

  // Налаштування
  SettingsPopup {
    id: settingsPopup
    window: root
    visible: false
  }

  // Спливаюче сповіщення (тост)
  NotifToast {
    id: notifToast
    anchorWindow: root
    visible: false
  }

  // IpcHandler для глобального виклику налаштувань
  IpcHandler {
    target: "settings"
    function toggle(): void {
      settingsPopup.toggle()
    }
  }

  // Лаунчер додатків
  LauncherPopup {
    id: launcherPopup
    window: root
    anchorItem: root.launcherWidget
    visible: false
  }

  // IpcHandler для глобального виклику лаунчера
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      launcherPopup.toggle()
    }
  }

  // Зв'язки: клік на віджеті → відкриває відповідний попап
  Connections { target: launcherWidget; function onClicked() { launcherPopup.toggle() } }
  Connections { target: clockWidget;    function onClicked() { calendarPopup.toggle() } }
  Connections { target: audioWidget;    function onClicked() { audioPopup.toggle() } }
  Connections { target: mprisWidget;    function onClicked() { mprisPopup.toggle() } }
  Connections { target: genshinWidget;  function onClicked() { genshinPopup.toggle() } }
  Connections { target: controlWidget;  function onClicked() { controlPopup.toggle() } }
  Connections { target: btWidget;       function onClicked() { btPopup.toggle() } }
  Connections { target: netWidget;      function onClicked() { netPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenWallpaperPopup() { controlPopup.visible = false; wallpaperPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenBtManager() { controlPopup.visible = false; btPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenNetManager() { controlPopup.visible = false; netPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenSettingsPopup() { controlPopup.visible = false; settingsPopup.toggle() } }
  Connections { target: genshinPopup;   function onRefreshRequested() { genshinMonitor.refreshNow() } }
}