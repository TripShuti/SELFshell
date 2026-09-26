// ============================================================
// quickshell/core/WallpaperController.qml — спільний список/застосування шпалер
// ============================================================
import Quickshell.Io
import QtQuick

// Єдиний механізм списку та застосування шпалер для WallpaperPopup
// і settings/WallpaperSection (було два дослівні дублі включно
// з гілкою themeMode==="black"). Невізуальний: процеси тримає Item,
// бо QtObject не приймає дочірні об'єкти. Старт — явно через
// refresh() (попап: при відкритті; секція: при створенні).
Item {
  id: root
  visible: false

  required property QtObject appConfig

  property var wallpapers: []
  property string statusText: ""
  // StdioCollector не чиститься між запусками — порожній список
  // відрізняємо від застарілого тексту прапором свіжих даних
  property bool _listGotData: false

  readonly property string paletteScriptPath: Qt.resolvedUrl("../scripts/update-palette.sh").toString().replace("file://", "")
  readonly property string wallpaperOnlyPath: Qt.resolvedUrl("../scripts/update-wallpaper-only.sh").toString().replace("file://", "")
  readonly property string listScriptPath: Qt.resolvedUrl("../scripts/update-palette.py").toString().replace("file://", "")

  function refresh() { listProc.running = true }

  function setWallpaper(path) {
    // повторний клік під час apply губиться б мовчки, а статус
    // "Setting wallpaper..." застрягав назавжди (onExited не приходить)
    if (applyProc.running) return
    var isStatic = root.appConfig.cfg.themeMode === "black"
    root.statusText = isStatic ? "\uF002 Setting wallpaper (palette stays)..." : "\uF002 Setting wallpaper..."
    applyProc.command = isStatic ? [root.wallpaperOnlyPath, path] : [root.paletteScriptPath, path]
    applyProc.running = true
  }

  // Отримує список файлів шпалер з директорії wp/
  Process {
    id: listProc
    stdout: listCollector
    command: ["python3", root.listScriptPath, "list"]
    onStarted: root._listGotData = false
    onExited: {
      running = false
      if (!root._listGotData) root.wallpapers = []
    }
  }

  StdioCollector {
    id: listCollector
    waitForEnd: true
    onDataChanged: {
      root._listGotData = true
      if (listCollector.text) {
        root.wallpapers = listCollector.text.trim().split("\n").filter(p => p.trim() !== "")
      }
    }
  }

  // Застосовує вибрану шпалеру через update-palette.sh
  Process {
    id: applyProc
    onExited: (exitCode) => {
      running = false
      // Помилку показуємо текстом, а не мовчки гасимо статусом
      if (exitCode !== 0) root.statusText = "\u26A0 Failed to set wallpaper (code " + exitCode + ")"
      // Статус "Setting wallpaper..." має зникнути через кілька секунд
      statusResetTimer.restart()
    }
  }

  Timer {
    id: statusResetTimer
    interval: 3000
    onTriggered: root.statusText = ""
  }
}
