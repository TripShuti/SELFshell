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
  readonly property QtObject osd: osdPopup
  function registerActive(name, item) {
    var copy = Object.assign({}, activeWidgets)
    copy[name] = item
    activeWidgets = copy
  }
  function unregisterActive(name) {
    if (!(name in activeWidgets)) return
    var copy = Object.assign({}, activeWidgets)
    delete copy[name]
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
  readonly property Item clipboardWidget: activeWidgets["clipboard"] ?? null
  readonly property Item btWidget: activeWidgets["bt"] ?? null
  readonly property Item netWidget: activeWidgets["net"] ?? null
  readonly property Item trayWidget: activeWidgets["tray"] ?? null
  readonly property Item kcdWidget: activeWidgets["kcd"] ?? null

  // Всі попапи бару (крім транзитних тостів): поки будь-який відкритий,
  // автоскривання не ховає бар
  property var popups: [
    calendarPopup, audioPopup, btPopup, netPopup, mprisPopup, workspacesPopup,
    keyboardPopup, genshinPopup, controlPopup, clipboardPopup, wallpaperPopup,
    settingsPopup, launcherPopup, trayPopup, pairingPopup, kcdPopup
  ]
  function anyPopupOpen() {
    for (var i = 0; i < root.popups.length; i++)
      if (root.popups[i].visible) return true
    return false
  }

  anchors {
    left: true
    right: true
    top: root.appConfig.cfg.barPos === "top"
    bottom: root.appConfig.cfg.barPos === "bottom"
  }

  implicitHeight: root.appConfig.cfg.barHeight
  color: "transparent"

  // --- Автоскривання ---
  // Layer-shell не вміє від'ємних margin-ів (вікно не з'їде за кромку),
  // тому прихований бар залишається на місці, але вміст (barContent)
  // анімовано виїжджає за кромку і гасне, а вся площа стає click-through
  // (mask обмежує input region лише смужкою-тригером). Лишається лише
  // 6px-смужка (revealStrip) біля кромки з "ручкою"-підказкою —
  // наведенням на неї бар повертається. exclusiveZone при цьому 0 —
  // вікна отримують весь екран.
  property bool barHidden: false
  readonly property bool autoHideOn: root.appConfig.cfg.barAutoHide

  exclusiveZone: (root.autoHideOn && root.barHidden) ? 0 : root.appConfig.cfg.barHeight

  // Сховати бар не вийшло через події hover: watchdog-сиблінг ПІД
  // пігулками (z:-1000) не отримував onExited, коли курсор ішов з панелі
  // через віджет (hover доставляється лише по ланцюгу "лист → предки",
  // сиблінги нижче верхнього не ховеряться взагалі). Тому:
  // - autoHideWatch лежить у barContent як БАТЬКО пігулок — він у ланцюзі
  //   предків будь-якого віджета, тож containsMouse вірний всюди і
  //   hover-візуали віджетів працюють як завжди; кліки/колесо проходять
  //   крізь нього (Qt.NoButton + відсутній onWheel — Qt 6 не приймає такі
  //   події і віддає їх нижче).
  // - revealWatch лежить НА РІВНІ вікна на смужці-тригері: прихований
  //   barContent разом з autoHideWatch виїжджає за кромку, тож hover на
  //   смужці ловить саме revealWatch. Він заввишки 6px — hover-крадіжка
  //   у видимому стані обмежена краєм пігулок і непомітна.
  // Автоскривання — event-driven, без опитування. Ховаємо через 400ms
  // після того як курсор пішов і немає відкритих попапів.
  Timer {
    id: hideDelay
    interval: 400
    repeat: false
    onTriggered: {
      if (root.anyPopupOpenState || autoHideWatch.containsMouse || revealWatch.containsMouse) return
      root.barHidden = true
    }
  }
  readonly property bool anyPopupOpenState: calendarPopup.visible || audioPopup.visible || btPopup.visible || netPopup.visible || mprisPopup.visible || workspacesPopup.visible || keyboardPopup.visible || genshinPopup.visible || controlPopup.visible || clipboardPopup.visible || wallpaperPopup.visible || settingsPopup.visible || launcherPopup.visible || trayPopup.visible || pairingPopup.visible || kcdPopup.visible || notifToast.visible || osdPopup.visible
  function _updateAutoHide() {
    if (!root.autoHideOn) { hideDelay.stop(); root.barHidden = false; return }
    if (root.anyPopupOpenState || autoHideWatch.containsMouse || revealWatch.containsMouse) {
      hideDelay.stop()
      if (root.barHidden) root.barHidden = false
    } else {
      if (!root.barHidden && !hideDelay.running) hideDelay.restart()
    }
  }
  Connections { target: autoHideWatch; function onContainsMouseChanged() { root._updateAutoHide() } }
  Connections { target: revealWatch; function onContainsMouseChanged() { root._updateAutoHide() } }
  onAnyPopupOpenStateChanged: _updateAutoHide()
  onAutoHideOnChanged: _updateAutoHide()

  // Смужка-тригер біля кромки: hover над нею (у прихованому стані це
  // єдина точка вводу — mask) ловить revealWatch. Вона ж малює ручку-
  // підказку — єдине видиме при прихованому барі.
  MouseArea {
    id: revealWatch
    visible: root.autoHideOn
    enabled: root.autoHideOn
    width: parent.width
    height: 6
    z: 1000
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    anchors.top: root.appConfig.cfg.barPos === "top" ? parent.top : undefined
    anchors.bottom: root.appConfig.cfg.barPos === "bottom" ? parent.bottom : undefined
    onEntered: { if (root.barHidden) root.barHidden = false }

    Rectangle {
      visible: root.barHidden
      width: 36
      height: 3
      radius: 1.5
      color: root.palette.fg
      opacity: 0.3
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: root.appConfig.cfg.barPos === "top" ? parent.top : undefined
      anchors.bottom: root.appConfig.cfg.barPos === "bottom" ? parent.bottom : undefined
      anchors.margins: 2
    }
  }

  required property QtObject palette
  required property QtObject appConfig
  required property QtObject kdeConnect

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
  Component { id: controlComp;    ControlWidget { window: root; anchors.fill: parent; unread: controlPopup.visible ? 0 : controlPopup.unread } }
  Component { id: clipboardComp;  ClipboardWidget { window: root; anchors.fill: parent } }
  Component { id: btComp;         BluetoothWidget { window: root; anchors.fill: parent } }
  Component { id: netComp;        NetWidget { window: root; anchors.fill: parent } }
  Component { id: trayComp;       TrayWidget { window: root; anchors.fill: parent } }
  Component { id: kcdComp;        KdeConnectWidget { window: root; anchors.fill: parent } }

  readonly property var widgetComponents: ({
    launcher: launcherComp, workspaces: workspacesComp, mpris: mprisComp,
    clock: clockComp, timer: timerComp, genshin: genshinComp,
    keyboard: keyboardComp, audio: audioComp, battery: batteryComp, control: controlComp,
    clipboard: clipboardComp,
    bt: btComp, net: netComp, tray: trayComp, kcd: kcdComp
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
    || name === "clipboard" || name === "kcd"
  }

  // Прихований бар не їсть кліки: input region вікна обмежується лише
  // смужкою-тригером (mask). При видимому барі mask = null — ввід на весь
  // екран вікна. (IgnoreArea з новіших версій Quickshell тут немає.)
  Region {
    id: hiddenMask
    x: 0
    y: root.appConfig.cfg.barPos === "top" ? 0 : root.height - 6
    width: root.width
    height: 6
  }
  mask: (root.autoHideOn && root.barHidden) ? hiddenMask : null

  // Контейнер пігулок — анімується при автоскриванні: вміст виїжджає за
  // кромку (layer-shell не вміє рухати саме вікно) і гасне.
  // Напрямок — від кромки, на якій стоїть бар (top: вгору, bottom: вниз).
  Item {
    id: barContent
    anchors.fill: parent
    state: root.barHidden ? "hidden" : "visible"

    states: [
      State { name: "visible"; PropertyChanges { target: barContent; y: 0; opacity: 1; scale: 1 } },
      State {
        name: "hidden"
        PropertyChanges {
          target: barContent
          y: root.appConfig.cfg.barPos === "top" ? -root.height : root.height
          opacity: 0
          scale: 0.85
        }
      }
    ]

    transitions: Transition {
      NumberAnimation { properties: "y,opacity,scale"; duration: root.appConfig.anim(350); easing.type: Easing.OutCubic }
    }

    // Watchdog hover-а (батько пігулок — див. коментар вище)
    MouseArea {
      id: autoHideWatch
      anchors.fill: parent
      hoverEnabled: true
      enabled: root.autoHideOn
      acceptedButtons: Qt.NoButton
      onEntered: { if (root.barHidden) root.barHidden = false }
    }

    // Ліва пігулка
    PillBar {
      anchors {
        left: parent.left
        leftMargin: root.appConfig.cfg.edgeMargin
        verticalCenter: parent.verticalCenter
      }
      visible: root.appConfig.cfg.leftPillEnabled
      height: pillHeight
      radius: root.appConfig.cfg.barRadius
      padding: root.appConfig.cfg.pillPadding
      contentSpacing: root.appConfig.cfg.contentSpacing
      lighten: root.appConfig.cfg.barLighten
      bgOpacity: root.appConfig.cfg.barBgOpacity
      borderWidth: root.appConfig.cfg.barBorderWidth
      appConfig: root.appConfig
      palette: root.palette
      orderModel: root.appConfig.cfg.leftOrder
      widgetComponents: root.widgetComponents
      needsFillHeight: root.widgetNeedsFillHeight
      registerActive: root.registerActive
      unregisterActive: root.unregisterActive
    }

    // Центральна пігулка
    PillBar {
      anchors.centerIn: parent
      visible: root.appConfig.cfg.centerPillEnabled
      height: pillHeight
      radius: root.appConfig.cfg.barRadius
      padding: root.appConfig.cfg.pillPadding
      contentSpacing: root.appConfig.cfg.contentSpacing
      lighten: root.appConfig.cfg.barLighten
      bgOpacity: root.appConfig.cfg.barBgOpacity
      borderWidth: root.appConfig.cfg.barBorderWidth
      appConfig: root.appConfig
      palette: root.palette
      orderModel: root.appConfig.cfg.centerOrder
      widgetComponents: root.widgetComponents
      needsFillHeight: root.widgetNeedsFillHeight
      registerActive: root.registerActive
      unregisterActive: root.unregisterActive
    }

    // Права пігулка
    PillBar {
      anchors {
        right: parent.right
        rightMargin: root.appConfig.cfg.edgeMargin
        verticalCenter: parent.verticalCenter
      }
      visible: root.appConfig.cfg.rightPillEnabled
      height: pillHeight
      radius: root.appConfig.cfg.barRadius
      padding: root.appConfig.cfg.pillPadding
      contentSpacing: root.appConfig.cfg.contentSpacing
      lighten: root.appConfig.cfg.barLighten
      bgOpacity: root.appConfig.cfg.barBgOpacity
      borderWidth: root.appConfig.cfg.barBorderWidth
      appConfig: root.appConfig
      palette: root.palette
      orderModel: root.appConfig.cfg.rightOrder
      widgetComponents: root.widgetComponents
      needsFillHeight: root.widgetNeedsFillHeight
      registerActive: root.registerActive
      unregisterActive: root.unregisterActive
    }
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
      if (root.appConfig.cfg.dndEnabled) return
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

  // Історія буфера обміну (SUPER+SHIFT+V). Коли віджет присутній у барі,
  // попап прив'язується до нього; інакше — до центру керування
  ClipboardPopup {
    id: clipboardPopup
    window: root
    anchorItem: root.clipboardWidget ?? root.controlWidget
    visible: false
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
      console.log("[shot] toast for: " + path)
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

  // Підтвердження Bluetooth-парингу (запити пише services/qs-bt-agent).
  // Попап центрований, без прив'язки до віджета: має з'явитись незалежно
  // від того, який попап відкритий зараз
  PairingAgent { id: pairingAgent }

  PairingPopup {
    id: pairingPopup
    window: root
    agent: pairingAgent
    visible: false
  }

  // Обидва центровані: попап парингу поверх менеджера Bluetooth виглядав
  // би месивом, тому під час парингу менеджер ховається (той самий
  // патерн, що controlPopup → settings/wallpaper вище). Стан тумблера
  // Discoverable не страждає — він живе в BlueZ до свого таймауту,
  // а не у видимості попапа
  Connections {
    target: pairingPopup
    function onVisibleChanged() {
      if (pairingPopup.visible && btPopup.visible) btPopup.visible = false
    }
  }

  // Телефон (kcd) — попап по кліку на віджет телефону
  KdeConnectPopup {
    id: kcdPopup
    window: root
    visible: false
  }

  // Міст: сповіщення з телефону → системний тост (поважає DND + kcdMuted)
  // Маркування: "Phone • WhatsApp" + іконка додатку (файл з kcd або тема) + phone badge
  Connections {
    target: kdeConnect
    function onNotificationReceived(notif) {
      if (root.appConfig.cfg.dndEnabled) return
      if (root.appConfig.cfg.kcdMuted) return
      notif.tracked = true
      var phoneApp = notif.appName ? "Phone • " + notif.appName : "Phone"
      // іконка додатку: payload.icon (файл з kcd fetch_icons) або підбір за ім'ям
      var iconSrc = notif.icon ?? ""
      if (!iconSrc) {
        var base = String(notif.appName ?? "").toLowerCase().replace(/\s+/g, "-")
        var cands = [base, "org." + base + ".desktop", base + "-desktop", base.replace(/^org\./, "")]
        // Telegram → org.telegram.desktop, WhatsApp → whatsapp, etc.
        if (base === "telegram") cands.unshift("org.telegram.desktop", "telegram-desktop")
        if (base === "whatsapp") cands.unshift("whatsapp", "whatsapp-desktop")
        iconSrc = "phone"
        for (var i = 0; i < cands.length; i++) {
          var c = cands[i]
          if (!c) continue
          var p = Quickshell.iconPath(c, true)
          if (p === "") p = Quickshell.iconPath(c, false)
          if (p !== "") { iconSrc = c; break }
        }
      }
      notif.isPhone = true
      notifToast.showNotif({
        appName: phoneApp,
        summary: notif.title,
        body: notif.text,
        appIcon: iconSrc,
        isPhone: true,
        actions: []
      })
      if (!controlPopup.visible) root.newNotifs++
    }
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

  // IpcHandler для глобального виклику історії буфера обміну (SUPER+SHIFT+V)
  IpcHandler {
    target: "clipboard"
    function toggle(): void {
      clipboardPopup.toggle()
    }
  }

  // IpcHandler для телефону (kcd)
  IpcHandler {
    target: "kcd"
    function toggle(): void {
      kcdPopup.toggle()
    }
  }

  // Зв'язки: клік на віджеті → відкриває відповідний попап
  Connections { target: launcherWidget; enabled: target !== null; function onClicked() { launcherPopup.toggle() } }
  Connections { target: clipboardWidget; enabled: target !== null; function onClicked() { clipboardPopup.toggle() } }
  Connections {
    target: workspacesWidget
    enabled: target !== null
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
  Connections { target: clockWidget; enabled: target !== null; function onClicked() { calendarPopup.toggle() } }
  Connections {
    target: keyboardWidget
    enabled: target !== null
    function onOpenPopup(anchor) {
      keyboardPopup.anchorItem = anchor
      keyboardPopup.toggle()
    }
  }
  Connections { target: audioWidget; enabled: target !== null; function onClicked() { audioPopup.toggle() } }
  Connections { target: mprisWidget; enabled: target !== null; function onClicked() { mprisPopup.toggle() } }
  Connections { target: genshinWidget; enabled: target !== null; function onClicked() { genshinPopup.toggle() } }
  Connections { target: controlWidget; enabled: target !== null; function onClicked() { controlPopup.toggle() } }
  Connections { target: btWidget; enabled: target !== null; function onClicked() { btPopup.toggle() } }
  Connections { target: netWidget; enabled: target !== null; function onClicked() { netPopup.toggle() } }
  Connections { target: kcdWidget; enabled: target !== null; function onClicked() { kcdPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenWallpaperPopup() { controlPopup.visible = false; wallpaperPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenBtManager() { controlPopup.visible = false; btPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenNetManager() { controlPopup.visible = false; netPopup.toggle() } }
  Connections { target: controlPopup;   function onOpenSettingsPopup() { controlPopup.visible = false; settingsPopup.toggle() } }
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
    enabled: target !== null
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