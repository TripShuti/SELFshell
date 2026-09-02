// ============================================================
// quickshell/core/IdleManager.qml — багаторівневе керування бездіяльністю: блокування, DPMS, suspend
// ============================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Менеджер бездіяльності з трьома рівнями (порядок: lock < dpms < suspend):
//
// Таймаути (секунди) налаштовуються в config.json:
//   idleLockTimeout / idleDpmsTimeout / idleSuspendTimeout
//
// Не знає про lockContext/sessionLock — спілкується через
// сигнали, які обробляє shell.qml.
Item {
  id: root

  required property QtObject appConfig

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

  // Лічильник граючих плеєрів — реактивний через сигнал isPlaying кожного делегата,
  // на відміну від старого циклу по count який не трекав зміну playing
  property int _playingCount: 0
  readonly property bool mediaPlaying: _playingCount > 0

  function _recalcPlaying() {
    var c = 0
    for (var i = 0; i < playerRepeater.count; ++i) {
      var it = playerRepeater.itemAt(i)
      if (it && it.playing) c++
    }
    _playingCount = c
  }

  // Стежить за MPRIS-плеєрами: коли хоч один відтворює медіа —
  // блокування не спрацює
  Repeater {
    id: playerRepeater
    model: Mpris.players

    delegate: Item {
      required property var modelData
      readonly property bool playing: modelData.isPlaying
      onPlayingChanged: root._recalcPlaying()
      Component.onCompleted: root._recalcPlaying()
      Component.onDestruction: root._recalcPlaying()
    }
  }

  // Рівень 1: блокування екрана.
  // timeout = 0 у config.json означає "never" — рівень вимкнено
  // (інакше IdleMonitor з нульовим таймаутом спрацює миттєво).
  IdleMonitor {
    timeout: root.appConfig.cfg.idleLockTimeout
    enabled: root.appConfig.cfg.idleLockTimeout > 0 && !root.mediaPlaying && !root.caffeineEnabled
    onIsIdleChanged: if (isIdle) root.lockRequested()
  }

  // Рівень 2: DPMS off — з автоматичним увімкненням
  IdleMonitor {
    timeout: root.appConfig.cfg.idleDpmsTimeout
    enabled: root.appConfig.cfg.idleDpmsTimeout > 0 && !root.mediaPlaying && !root.caffeineEnabled
    onIsIdleChanged: {
      dpmsProc.command = isIdle
        ? ["hyprctl", "dispatch", "dpms", "off"]
        : ["hyprctl", "dispatch", "dpms", "on"]
      dpmsProc.running = true
    }
  }

  // Рівень 3: suspend
  IdleMonitor {
    timeout: root.appConfig.cfg.idleSuspendTimeout
    enabled: root.appConfig.cfg.idleSuspendTimeout > 0 && !root.mediaPlaying && !root.caffeineEnabled
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
