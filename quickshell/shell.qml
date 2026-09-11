// ============================================================
// quickshell/shell.qml — кореневий компонент: блокування, idle, бар
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "core"
import "services"
import "monitors"
import QtQuick

ShellRoot {
  id: root

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
  // CavaMonitor і NotificationServer лишаються в Bar свідомо — вони
  // прив'язані до екрана (візуалізатор/тост)).
  GenshinMonitor { id: genshinMonitorSvc; appConfig: rootAppConfig }
  SelfTrackMonitor { id: selftrackMonitorSvc; appConfig: rootAppConfig }

  PowerProfileService { id: powerProfileService }

  PacmanService { id: pacmanService }

  LockContext { id: lockContext }

  WlSessionLock {
    id: sessionLock
    locked: lockContext.locked

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
    function onSuspendRequested() {
      lockContext.locked = true
      suspendDelay.restart()
    }
  }

  Timer {
    id: suspendDelay
    interval: 400
    onTriggered: {
      if (!lockContext.locked) lockContext.locked = true
      suspendProc.command = ["/usr/bin/systemctl", "suspend"]
      suspendProc.running = true
    }
  }

  IpcHandler {
    target: "palette-reload"
    function reload(): void { paletteService.reload() }
  }

  IpcHandler {
    target: "lockscreen"

    function lock(): void {
      lockContext.locked = true
    }

    function toggle(): void {
      lockContext.locked = !lockContext.locked
    }
  }

  // Лочимо екран ПЕРЕД сном (для lid close, power button — шляхів,
  // які ми не контролюємо). Слухаємо PrepareForSleep(true) від logind.
  // Використовуємо SplitParser замість grep — без sh -c пайплайну та без
  // накопичення тексту в StdioCollector (ротація після обробки).
  SplitParser {
    id: sleepParser
    splitMarker: "\n"
    onRead: data => {
      if (String(data ?? "").includes("boolean true"))
        lockContext.locked = true
    }
  }

  Process {
    id: sleepMonitor
    command: ["systemd-inhibit",
      "--what=sleep",
      "--mode=delay",
      "--who=quickshell-lockscreen",
      "--why=Lock screen before suspend",
      "dbus-monitor", "--system",
      "type=signal,sender=org.freedesktop.login1,interface=org.freedesktop.login1.Manager,member=PrepareForSleep"]
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
      palette: paletteService
      appConfig: rootAppConfig
      kdeConnect: kdeConnectService
      genshinMonitor: genshinMonitorSvc
      selftrackMonitor: selftrackMonitorSvc
      powerProfiles: powerProfileService
      pacmanUpdates: pacmanService
      idleManager: idleManagerSvc
    }
  }
}
