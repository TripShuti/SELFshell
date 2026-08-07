// ============================================================
// shell.qml — кореневий компонент: блокування, idle, бар
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "core"
import QtQuick

ShellRoot {
  id: root

  PaletteService { id: paletteService }

  // Спільний стан конфігурації — єдиний інстанс на весь шелл.
  // Доступний барам через window.appConfig, моніторам — напряму.
  AppConfig { id: rootAppConfig }

  LockContext { id: lockContext }

  WlSessionLock {
    id: sessionLock
    locked: lockContext.locked

    WlSessionLockSurface {
      LockSurface {
        anchors.fill: parent
        context: lockContext
        palette: paletteService
      }
    }
  }

  Connections {
    target: lockContext
    function onUnlocked() {
      lockContext.locked = false
    }
  }

  IdleManager {
    id: idleManager
    appConfig: rootAppConfig
  }

  Connections {
    target: idleManager
    function onLockRequested() {
      lockContext.locked = true
    }
    function onSuspendRequested() {
      lockContext.locked = true
      suspendProc.command = ["systemctl", "suspend"]
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
  StdioCollector {
    id: sleepCollector
    waitForEnd: false
    onDataChanged: {
      if (text.includes("boolean true"))
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
      "sh", "-c",
      "dbus-monitor --system "
      + "'type=signal,sender=org.freedesktop.login1,"
      + "interface=org.freedesktop.login1.Manager,"
      + "member=PrepareForSleep' 2>/dev/null "
      + "| grep --line-buffered 'boolean true'"]
    stdout: sleepCollector
    running: true

    // Якщо пайплайн з якоїсь причини помре (гикання D-Bus сесії тощо) —
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
    Bar { palette: paletteService; appConfig: rootAppConfig }
  }
}
