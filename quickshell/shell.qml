// ============================================================
// quickshell/shell.qml — кореневий компонент: блокування, idle, бар
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "core"
import "services"
import "monitors"
import QtQuick

ShellRoot {
  id: root

  property bool suspendPending: false
  property bool sleepPreparing: false
  property int sleepCycle: 0

  Binding { target: Quickshell; property: "watchFiles"; value: !lockContext.locked && !wallpaperSvc.applying }

  function requestSuspend() {
    if (root.suspendPending || suspendProc.running) return
    root.suspendPending = true
    lockContext.locked = true
    suspendTimeout.restart()
    root.continueSuspend()
  }

  function continueSuspend() {
    if (!sessionLock.secure) return
    if (root.sleepPreparing) sleepMonitor.write("secure " + root.sleepCycle + "\n")
    if (!root.suspendPending) return
    root.suspendPending = false
    suspendTimeout.stop()
    suspendProc.command = ["/usr/bin/systemctl", "suspend"]
    suspendProc.running = true
  }

  property var bars: []
  function registerBar(bar) { root.bars = root.bars.concat([bar]) }
  function unregisterBar(bar) {
    root.bars = root.bars.filter(b => b !== bar)
    if (root.pairingBar === bar) root.pairingBar = root.activeBar()
    if (root.phonePairingBar === bar) root.phonePairingBar = root.activeBar()
  }
  function activeBar() {
    var name = Hyprland.focusedMonitor?.name ?? ""
    for (var i = 0; i < root.bars.length; i++) {
      if (root.bars[i].screen?.name === name) return root.bars[i]
    }
    return root.bars.length > 0 ? root.bars[0] : null
  }
  function isActiveBar(bar) { return root.activeBar() === bar }
  function togglePopup(name) { root.activeBar()?.invokePopup(name) }

  WallpaperController { id: wallpaperSvc; appConfig: rootAppConfig }
  AudioEq { id: audioEqSvc }
  MprisService { id: mediaPlayerSvc; appConfig: rootAppConfig }
  property var pairingBar: null
  property var phonePairingBar: null
  PairingAgent {
    id: pairingAgentSvc
    onRequestChanged: if (request) root.pairingBar = root.activeBar()
  }
  Connections {
    target: kdeConnectService
    function onPendingPairRequestChanged() {
      if (kdeConnectService.pendingPairRequest) root.phonePairingBar = root.activeBar()
    }
  }
  CavaMonitor {
    id: cavaMonitorSvc
    appConfig: rootAppConfig
    active: {
      for (var i = 0; i < root.bars.length; i++) {
        if (root.bars[i].visualizationActive) return true
      }
      return false
    }
  }
  NotificationServer {
    id: notificationServerSvc
    actionsSupported: true
    bodySupported: true
    imageSupported: true
    onNotification: notif => root.activeBar()?.handleSystemNotification(notif)
  }
  IpcHandler { target: "settings"; function toggle(): void { root.togglePopup("settings") } }
  IpcHandler {
    target: "configuration"
    function set(key: string, value: string): bool { return rootAppConfig.setValue(key, value) }
    function reset(): void { rootAppConfig.resetCfg() }
  }
  IpcHandler { target: "launcher"; function toggle(): void { root.togglePopup("launcher") } }
  IpcHandler { target: "control"; function toggle(): void { root.togglePopup("control") } }
  IpcHandler { target: "clipboard"; function toggle(): void { root.togglePopup("clipboard") } }
  IpcHandler { target: "kcd"; function toggle(): void { root.togglePopup("kcd") } }
  IpcHandler { target: "audio"; function toggle(): void { root.togglePopup("audio") } }
  IpcHandler { target: "selftrack"; function toggle(): void { root.togglePopup("selftrack") } }
  IpcHandler {
    target: "osd"
    function volume(): void { root.activeBar()?.osd.showVolume() }
    function brightness(): void { root.activeBar()?.osd.showBrightness() }
  }

  PaletteService { id: paletteService }

  // Спільний стан конфігурації — єдиний інстанс на весь шелл.
  // Доступний барам через window.appConfig, моніторам — напряму.
  AppConfig { id: rootAppConfig }

  KdeConnectService { id: kdeConnectService; enabled: rootAppConfig.cfg.kcdEnabled; dnd: rootAppConfig.cfg.kcdDndEnabled }

  // Екранно-незалежні монітори даних — один інстанс на процес (раніше жили
  // в Bar і множились на кількість моніторів: N× genshin sync ризикував
  // HoYoLAB rate-limit, N× selftrack export. Імена з Svc-суфіксом навмисно:
  // в делегаті Variants нижче Bar має однойменні required-властивості, і
  // `genshinMonitor: genshinMonitor` замкнулось би саме на себе (binding loop).
  GenshinMonitor { id: genshinMonitorSvc; appConfig: rootAppConfig }
  SelfTrackMonitor { id: selftrackMonitorSvc; appConfig: rootAppConfig }

  PowerProfileService { id: powerProfileService }
  BatteryService {
    id: batterySvc
    appConfig: rootAppConfig
    powerProfiles: powerProfileService
    onLowBattery: percent => root.activeBar()?.toast.showNotif({
      appName: "Battery", summary: "Low battery (" + percent + "%)",
      body: "Connect the charger.", appIcon: "battery-low", actions: []
    })
  }

  PacmanService { id: pacmanService }

  LockContext { id: lockContext }

  WlSessionLock {
    id: sessionLock
    locked: lockContext.locked
    onSecureChanged: root.continueSuspend()

    WlSessionLockSurface {
      LockSurface {
        anchors.fill: parent
        context: lockContext
        palette: paletteService
        appConfig: rootAppConfig
      }
    }
  }

  Connections {
    target: lockContext
    function onUnlocked() {
      lockContext.locked = false
    }
  }

  // Ім'я з Svc-суфіксом навмисно — та сама причина, що в моніторів вище:
  // `idleManager: idleManager` замкнулось би саме на себе (binding loop).
  IdleManager {
    id: idleManagerSvc
    appConfig: rootAppConfig
  }

  Connections {
    target: idleManagerSvc
    function onLockRequested() {
      lockContext.locked = true
    }
    function onSuspendRequested() { root.requestSuspend() }
  }

  Timer {
    id: suspendTimeout
    interval: 5000
    onTriggered: {
      root.suspendPending = false
      console.warn("Suspend cancelled: compositor has not confirmed the screen lock")
    }
  }

  IpcHandler {
    target: "palette-reload"
    function reload(): void { paletteService.reload() }
  }

  IpcHandler {
    target: "lockscreen"
    function suspend(): void { root.requestSuspend() }
    function isLocked(): bool { return lockContext.locked }
    // Перевірка і вихід виконуються в одному виклику: лок не може
    // увімкнутися між перевіркою CLI та зупинкою процеса.
    function quitIfUnlocked(): void { if (!lockContext.locked && !wallpaperSvc.applying) Qt.quit() }

    function lock(): void {
      lockContext.locked = true
    }

    // Навмисно тільки лочить: розлок без PAM через IPC дозволяв би
    // будь-якому процесу юзера зняти лок екрана без пароля.
    // Розлок — лише через PAM (LockContext.unlocked → locked = false).
    function toggle(): void {
      if (!lockContext.locked) lockContext.locked = true
    }
  }

  // Helper тримає delay-FD між циклами сну й закриває його після secure.
  SplitParser {
    id: sleepParser
    splitMarker: "\n"
    onRead: data => {
      var event
      try { event = JSON.parse(String(data)) } catch (e) { return }
      root.sleepPreparing = event.sleeping === true
      root.sleepCycle = event.cycle ?? 0
      if (root.sleepPreparing) {
        lockContext.locked = true
        root.continueSuspend()
      }
    }
  }

  Process {
    id: sleepMonitor
    command: ["python3", Qt.resolvedUrl("scripts/sleep_guard.py").toString().replace("file://", "")]
    stdinEnabled: true
    stdout: sleepParser
    running: true

    // Якщо процес з якоїсь причини помре (гикання D-Bus сесії тощо) —
    // перезапускаємо, а не лишаємось мовчки без захисту до рестарту
    // quickshell. Невелика затримка перед рестартом, щоб не спамити
    // спробами, якщо причина смерті постійна (наприклад dbus взагалі
    // недоступний).
    onExited: (exitCode) => {
      console.warn("sleepMonitor exited (code " + exitCode + "), restarting in 2s")
      restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 2000
    onTriggered: sleepMonitor.running = true
  }

  Process {
    id: suspendProc
    onExited: running = false
  }

  Variants {
    model: Quickshell.screens
    Bar {
      shellController: root
      battery: batterySvc
      audioEq: audioEqSvc
      mediaPlayer: mediaPlayerSvc
      cavaMonitor: cavaMonitorSvc
      notifServer: notificationServerSvc
      pairingAgent: pairingAgentSvc
      palette: paletteService
      appConfig: rootAppConfig
      kdeConnect: kdeConnectService
      genshinMonitor: genshinMonitorSvc
      selftrackMonitor: selftrackMonitorSvc
      powerProfiles: powerProfileService
      pacmanUpdates: pacmanService
      wallpaperController: wallpaperSvc
      idleManager: idleManagerSvc
    }
  }
}
