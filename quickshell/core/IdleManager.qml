// ============================================================
// IdleManager.qml — багаторівневе керування бездіяльністю:
// блокування, DPMS, suspend
// ============================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

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

  readonly property bool mediaPlaying: {
    for (var i = 0; i < playerRepeater.count; ++i) {
      var item = playerRepeater.itemAt(i)
      if (item && item.playing) return true
    }
    return false
  }

  // Стежить за MPRIS-плеєрами: коли хоч один відтворює медіа —
  // блокування не спрацює
  Repeater {
    id: playerRepeater
    model: Mpris.players

    delegate: Item {
      required property var modelData
      readonly property bool playing: modelData.isPlaying
    }
  }

  // Рівень 1: блокування екрана (5 хв)
  IdleMonitor {
    timeout: 300
    enabled: !root.mediaPlaying
    onIsIdleChanged: if (isIdle) root.lockRequested()
  }

  // Рівень 2: DPMS off (6 хв) — з автоматичним увімкненням
  IdleMonitor {
    timeout: 360
    enabled: !root.mediaPlaying
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
    enabled: !root.mediaPlaying
    onIsIdleChanged: if (isIdle) root.suspendRequested()
  }

  Process {
    id: dpmsProc
    onExited: running = false
  }
}
