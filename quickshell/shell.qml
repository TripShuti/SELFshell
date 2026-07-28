// ============================================================
// shell.qml — кореневий компонент: панель, idle-менеджер,
// затемнювач, IPC для запуску lockscreen окремим процесом
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
  // --- Idle-менеджер (заміна hypridle) ---
  IdleManager { id: idleManager }

  Connections {
    target: idleManager
    function onLockRequested() {
      launchLockscreen()
    }
    function onSuspendRequested() {
      suspendProc.command = ["systemctl", "suspend"]
      suspendProc.running = true
    }
  }

  // --- IPC для зовнішнього виклику (SUPER+L, ControlManager) ---
  IpcHandler {
    target: "lockscreen"

    function lock(): void {
      launchLockscreen()
    }

    function toggle(): void {
      launchLockscreen()
    }
  }

  // Запускає lockscreen окремим процесом.
  // Після розблокування lockscreen.qml сам викликає Qt.quit() —
  // це єдиний правильний спосіб для ext-session-lock-v1.
  function launchLockscreen() {
    lockProc.command = ["quickshell", "-n", "-p", "/home/trip/.config/quickshell/lockscreen.qml"]
    lockProc.running = true
  }

  Process { id: lockProc; onExited: running = false }
  Process { id: suspendProc; onExited: running = false }

  // --- Панель на кожен монітор ---
  Variants {
    model: Quickshell.screens

    Bar {}
  }
}
