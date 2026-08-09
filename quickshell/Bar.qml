// ============================================================
// Bar.qml — головна панель системи (top bar) з віджетами,
// попапами та моніторами
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "core"
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
  // Тостер для віджетів (battery): явна властивість замість id-хаків між файлами
  readonly property QtObject toast: notifToast
  function registerActive(name, item) {
    var copy = Object.assign({}, activeWidgets)
    copy[name] = item
    activeWidgets = copy
  }

  readonly property Item launcherWidget: activeWidgets["launcher"] ?? null
  readonly property Item workspacesWidget: activeWidgets["workspaces"] ?? null
  readonly property Item clockWidget: activeWidgets["clock"] ?? null
  readonly property Item mprisWidget: activeWidgets["mpris"] ?? null
  readonly property Item genshinWidget: activeWidgets["genshin"] ?? null
  readonly property Item keyboardWidget: activeWidgets["keyboard"] ?? null
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

  implicitHeight: root.appConfig.barHeight
  color: "transparent"
  exclusiveZone: root.appConfig.barHeight

  required property QtObject palette
  required property QtObject appConfig

  // --- Шаблони компонентів для динамічного рендеру пігулок ---
  // Loader.sourceComponent бере звідси потрібний тип за іменем віджета.
  // Layout.fillHeight/alignment ставляться на сам Loader у делегаті Repeater-а
  // всередині PillBar. Для тих, кому потрібен fillHeight (Mpris/Audio), сам
  // item заповнює Loader через anchors.fill: parent.
  Component { id: launcherComp;   LauncherWidget { window: root; anchors.fill: parent } }
  Component { id: workspacesComp; WorkspacesWidget { window: root } }
  Component { id: mprisComp;      MprisWidget { window: root; anchors.fill: parent; cavBars: cavaMonitor.bars } }
  Component { id: clockComp;      ClockWidget { window: root } }
  Component { id: timerComp;      TimerWidget { window: root; anchors.fill: parent; appConfig: root.appConfig } }
  Component { id: genshinComp;    GenshinWidget { window: root; anchors.fill: parent; resinText: genshinMonitor.resinText; resinClass: genshinMonitor.resinClass } }
  Component { id: keyboardComp;   KeyboardLayoutWidget { window: root; anchors.fill: parent } }
  Component { id: audioComp;      AudioWidget { window: root; anchors.fill: parent } }
  Component { id: batteryComp;    BatteryWidget { window: root; anchors.fill: parent } }
  Component { id: controlComp;    ControlWidget { window: root; anchors.fill: parent; unread: controlPopup.unread } }
  Component { id: btComp;         BluetoothWidget { window: root; anchors.fill: parent } }
  Component { id: netComp;        NetWidget { window: root; anchors.fill: parent } }
  Component { id: trayComp;       TrayWidget { window: root; anchors.fill: parent } }

  readonly property var widgetComponents: ({
    launcher: launcherComp, workspaces: workspacesComp, mpris: mprisComp,
    clock: clockComp, timer: timerComp, genshin: genshinComp,
    keyboard: keyboardComp, audio: audioComp, battery: batteryComp, control: controlComp,
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
    || name === "keyboard" || name === "battery"
  }

  // Ліва пігулка
  PillBar {
    anchors {
      left: parent.left
      leftMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: pillHeight
    radius: root.appConfig.barRadius
    appConfig: root.appConfig
    palette: root.palette
    orderModel: root.appConfig.leftOrder
    widgetComponents: root.widgetComponents
    needsFillHeight: root.widgetNeedsFillHeight
    registerActive: root.registerActive
  }

  // Центральна пігулка
  PillBar {
    anchors.centerIn: parent
    height: pillHeight
    radius: root.appConfig.barRadius
    appConfig: root.appConfig
    palette: root.palette
    orderModel: root.appConfig.centerOrder
    widgetComponents: root.widgetComponents
    needsFillHeight: root.widgetNeedsFillHeight
    registerActive: root.registerActive
  }

  // Права пігулка
  PillBar {
    anchors {
      right: parent.right
      rightMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: pillHeight
    radius: root.appConfig.barRadius
    appConfig: root.appConfig
    palette: root.palette
    orderModel: root.appConfig.rightOrder
    widgetComponents: root.widgetComponents
    needsFillHeight: root.widgetNeedsFillHeight
    registerActive: root.registerActive
  }

  CalendarPopup {
    id: calendarPopup
    window: root
    anchorItem: root.clockWidget
    visible: false
  }

  AudioMixerPopup {
    id: audioPopup
    window: root
    anchorItem: root.audioWidget
    visible: false
  }

  BluetoothPopup {
    id: btPopup
    window: root
    visible: false
  }

  NetworkPopup {
    id: netPopup
    window: root
    visible: false
  }

  // Сервер сповіщень — ловить системні сповіщення
  NotificationServer {
    id: notifServer
    actionsSupported: true
    bodySupported: true
    imageSupported: true

    onNotification: (notif) => {
      // DND — повністю ховає сповіщення (тост, список, звук)
      if (root.appConfig.dndEnabled) return
      notif.tracked = true
      notifToast.showNotif(notif)
      // Лічильник непрочитаних: росте, поки центр керування закритий
      if (!controlPopup.visible) root.newNotifs++
    }
  }

  // Лічильник нових сповіщень (badge на ControlWidget, скидається при відкритті)
  property int newNotifs: 0

  // Монітор аудіо-візуалізації (cava) — працює, коли візуалізатор реально
  // видно: у віджеті панелі під час відтворення або у відкритому попапі.
  // Інакше cava на 30 fps спалював би CPU вхолосту весь день.
  CavaMonitor {
    id: cavaMonitor
    appConfig: root.appConfig
    active: mprisPopup.visible || (root.mprisWidget?.player?.isPlaying ?? false)
  }

  GenshinMonitor {
    id: genshinMonitor
    appConfig: root.appConfig
  }

  MprisPopup {
    id: mprisPopup
    window: root
    anchorItem: root.mprisWidget
    visible: false
    cavBars: cavaMonitor.bars
  }

  // Попап воркспейса: вікна стола, навігація (ПКМ на номері)
  WorkspacesPopup {
    id: workspacesPopup
    window: root
    anchorItem: root.workspacesWidget
    visible: false
  }

  // Попап вибору розкладки (ПКМ на віджеті розкладки)
  KeyboardLayoutPopup {
    id: keyboardPopup
    window: root
    anchorItem: root.keyboardWidget
    visible: false
  }

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
  ControlPopup {
    id: controlPopup
    window: root
    anchorItem: root.controlWidget
    visible: false
    notificationsModel: notifServer.trackedNotifications
  }

  WallpaperPopup {
    id: wallpaperPopup
    window: root
    visible: false
  }

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
    muted: controlPopup.muted
  }

  // OSD-індикатор гучності/яскравості (викликається через IPC з binds.lua)
  OsdPopup {
    id: osdPopup
    anchorWindow: root
    visible: false
  }

  // IpcHandler: XF86-клавіші (binds.lua) → показ OSD
  IpcHandler {
    target: "osd"
    function volume(): void {
      osdPopup.showVolume()
    }
    function brightness(): void {
      osdPopup.showBrightness()
    }
  }

  // Кнопка скріншота в ControlPopup → тост «Screenshot saved» з кнопкою Open
  Connections {
    target: controlPopup
    function onScreenshotTaken(path) {
      notifToast.showNotif({
        appName: "Screenshot",
        summary: "Saved to " + path,
        body: "",
        appIcon: "camera-photo",
        actions: [{
          identifier: "open",
          text: "Open",
          invoke: (function() {
            openShotProc.command = ["xdg-open", path]
            openShotProc.running = true
          })
        }]
      })
      if (controlPopup.visible) controlPopup.visible = false
    }
  }

  Process {
    id: openShotProc
    onExited: running = false
  }

  // IpcHandler для глобального виклику налаштувань
  IpcHandler {
    target: "settings"
    function toggle(): void {
      settingsPopup.toggle()
    }
  }

  LauncherPopup {
    id: launcherPopup
    window: root
    anchorItem: root.launcherWidget
    visible: false
  }

  // Меню системного трею — QML-рендер через QsMenuOpener.
  // anchorItem оновлюється при кожному відкритті (під яку саме іконку).
  TrayMenuPopup {
    id: trayPopup
    window: root
    anchorItem: root.trayWidget
    visible: false
  }

  // IpcHandler для глобального виклику лаунчера
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      launcherPopup.toggle()
    }
  }

  // IpcHandler для глобального виклику центру керування (SUPER+Escape)
  IpcHandler {
    target: "control"
    function toggle(): void {
      controlPopup.toggle()
    }
  }

  // Зв'язки: клік на віджеті → відкриває відповідний попап
  Connections { target: launcherWidget; function onClicked() { launcherPopup.toggle() } }
  Connections {
    target: workspacesWidget
    // ПКМ на тій же столі — закрити; на іншій — перевідкрити під нею
    function onOpenPopup(ws, anchor) {
      if (workspacesPopup.visible && workspacesPopup.workspace === ws) {
        workspacesPopup.close()
        return
      }
      workspacesPopup.workspace = ws
      workspacesPopup.anchorItem = anchor
      if (!workspacesPopup.visible) workspacesPopup.visible = true
      workspacesPopup.positionUnderAnchor()
    }
  }
  Connections { target: clockWidget;    function onClicked() { calendarPopup.toggle() } }
  Connections {
    target: keyboardWidget
    function onOpenPopup(anchor) {
      keyboardPopup.anchorItem = anchor
      keyboardPopup.toggle()
    }
  }
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
  Connections {
    target: root
    function onNewNotifsChanged() {
      if (root.controlWidget) root.controlWidget.unread = root.newNotifs
    }
  }
  Connections {
    target: controlPopup
    function onVisibleChanged() {
      // Відкрили центр керування — сповіщення "прочитані"
      if (controlPopup.visible) root.newNotifs = 0
    }
  }
  Connections { target: genshinPopup;   function onRefreshRequested() { genshinMonitor.refreshNow() } }
  Connections {
    target: trayWidget
    // Клік на тій же іконці — закрити; на іншій — перевідкрити під нею
    function onMenuRequested(menu, anchor) {
      if (trayPopup.visible && trayPopup.menu === menu) {
        trayPopup.close()
        return
      }
      if (trayPopup.visible) trayPopup.visible = false
      trayPopup.menu = menu
      trayPopup.anchorItem = anchor
      trayPopup.visible = true
    }
  }
}