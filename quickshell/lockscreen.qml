// ============================================================
// lockscreen.qml — окремий процес для блокування екрана.
// Запускається через IPC (qs ipc call lockscreen lock)
// або вручну: quickshell -p lockscreen.qml
// Виходить (Qt.quit()) при успішному розблокуванні.
// ============================================================
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
  LockContext { id: lockContext }

  WlSessionLock {
    id: sessionLock
    locked: true

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
      sessionLock.locked = false
      Qt.quit()
    }
  }
}
