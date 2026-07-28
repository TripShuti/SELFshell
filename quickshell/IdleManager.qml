// ============================================================
// IdleManager.qml — багаторівневе керування бездіяльністю:
// блокування, DPMS, suspend
// ============================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Менеджер бездіяльності з трьома рівнями:
//   300s — блокування (lockRequested)
//   360s — DPMS off
//   900s — suspend (suspendRequested)
//
// Не знає про lockContext/sessionLock — спілкується через
// сигнали, які обробляє shell.qml.
Item {
  id: root

  signal lockRequested()
  signal suspendRequested()

  // Рівень 1: блокування екрана (5 хв)
  IdleMonitor {
    timeout: 300
    onIsIdleChanged: if (isIdle) root.lockRequested()
  }

  // Рівень 2: DPMS off (6 хв) — з автоматичним увімкненням
  IdleMonitor {
    timeout: 360
    onIsIdleChanged: {
      dpmsProc.command = isIdle
        ? ["hyprctl", "dispatch", "dpms", "off"]
        : ["hyprctl", "dispatch", "dpms", "on"]
      dpmsProc.running = true
    }
  }

  // Рівень 3: suspend (15 хв)
  IdleMonitor {
    timeout: 900
    onIsIdleChanged: if (isIdle) root.suspendRequested()
  }

  Process {
    id: dpmsProc
    onExited: running = false
  }
}
