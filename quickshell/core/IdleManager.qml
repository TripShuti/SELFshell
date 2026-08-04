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

  // Caffeine mode: стан з control-state.json (пишеться кнопкою в ControlPopup).
  // Стежимо за змінами файлу на диску (watchChanges → reload) і перечитуємо
  // значення імперативно в onDataChanged — так само, як PaletteService.
  // Прямий біндинг на text() ненадійний, бо виклик функції не створює
  // залежності bindings QML.
  property bool caffeineEnabled: false

  function _parseCaffeine(text) {
    if (!text) { root.caffeineEnabled = false; return }
    try {
      var data = JSON.parse(text)
      root.caffeineEnabled = data.caffeine === true
    } catch (e) {
      root.caffeineEnabled = false
    }
  }

  FileView {
    id: caffeineFile
    path: Qt.resolvedUrl("../data/control-state.json")
    watchChanges: true
    onFileChanged: this.reload()
    onDataChanged: root._parseCaffeine(caffeineFile.text())
  }

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
    enabled: !root.mediaPlaying && !root.caffeineEnabled
    onIsIdleChanged: if (isIdle) root.lockRequested()
  }

  // Рівень 2: DPMS off (6 хв) — з автоматичним увімкненням
  IdleMonitor {
    timeout: 360
    enabled: !root.mediaPlaying && !root.caffeineEnabled
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
    enabled: !root.mediaPlaying && !root.caffeineEnabled
    onIsIdleChanged: if (isIdle) root.suspendRequested()
  }

  Process {
    id: dpmsProc
    onExited: running = false
  }

  // Гарантоване читання початкового стану: preload асинхронний, тому
  // dataChanged може прийти вже після того, як монітори стартують.
  Component.onCompleted: root._parseCaffeine(caffeineFile.text())
}
