// ============================================================
// shell.qml — кореневий компонент: панель, idle-менеджер,
// вбудований lockscreen через WlSessionLock, моніторинг сну
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
  LockContext { id: lockContext }

  WlSessionLock {
    id: sessionLock
    locked: lockContext.locked

    WlSessionLockSurface {
      LockSurface {
        anchors.fill: parent
        context: lockContext
      }
    }
  }

  Connections {
    target: lockContext
    function onUnlocked() {
      lockContext.locked = false
    }
  }

  // --- Idle-менеджер (заміна hypridle) ---
  IdleManager { id: idleManager }

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

  // --- IPC для зовнішнього виклику (SUPER+L, ControlManager) ---
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
    command: ["sh", "-c",
      "dbus-monitor --system "
      + "'type=signal,sender=org.freedesktop.login1,"
      + "interface=org.freedesktop.login1.Manager,"
      + "member=PrepareForSleep' 2>/dev/null "
      + "| grep --line-buffered 'boolean true'"]
    stdout: sleepCollector
    running: true
  }

  Process {
    id: suspendProc
    onExited: running = false
  }

  // --- Панель на кожен монітор ---
  Variants {
    model: Quickshell.screens
    Bar {}
  }
}
