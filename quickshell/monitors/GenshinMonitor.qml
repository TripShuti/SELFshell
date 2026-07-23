// ============================================================
// GenshinMonitor.qml — монітор Genshin Impact (опитування API)
// ============================================================
import Quickshell
import Quickshell.Io
import "../Config.js" as Config
import QtQuick

// Монітор Genshin Impact — періодично опитує API, оновлює дані
Item {
  id: root

  property string resinText: "\uF737 0/200"
  property string tooltip: "Завантаження..."
  property string resinClass: "normal"

  // Статус ручного оновлення
  property string refreshStatus: "idle"
  property string refreshMessage: ""

  // Примусове оновлення (викликається з GenshinPopup)
  function refreshNow() {
    if (manualProc.running) return
    root.refreshStatus = "loading"
    root.refreshMessage = ""
    manualProc.running = true
  }

  // Застосовує результат ручного оновлення
  function _applyResult(text) {
    try {
      var obj = JSON.parse(text)
      root.resinText = obj.text ?? root.resinText
      root.tooltip = obj.tooltip ?? root.tooltip
      root.resinClass = obj.class ?? root.resinClass
      root.refreshStatus = "ok"
      root.refreshMessage = "Оновлено"
    } catch (e) {
      root.refreshStatus = "error"
      root.refreshMessage = "Помилка парсингу: " + e
    }
    resetTimer.restart()
  }

  // Фонове опитування кожні 60 секунд
  Process {
    id: proc
    command: ["sh", "-c", "while true; do python3 $HOME/.config/quickshell/scripts/genshin_stats.py; sleep 60; done"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return

        try {
          var obj = JSON.parse(text)
          root.resinText = obj.text ?? "\uF737 ?"
          root.tooltip = obj.tooltip ?? "Немає даних"
          root.resinClass = obj.class ?? "normal"
        } catch (e) {
          root.resinText = "\uF737 !"
          root.tooltip = "Помилка парсингу: " + e
        }
      }
    }
  }

  // Ручне оновлення — окремий процес
  Process {
    id: manualProc
    command: ["sh", "-c", "python3 $HOME/.config/quickshell/scripts/genshin_stats.py"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var text = (data ?? "").trim()
        if (text !== "") root._applyResult(text)
      }
    }

    onExited: (code) => {
      if (code !== 0 && root.refreshStatus === "loading") {
        root.refreshStatus = "error"
        root.refreshMessage = "Помилка запуску"
        resetTimer.restart()
      }
    }
  }

  // Скидає статус через 2.5 секунди після оновлення
  Timer {
    id: resetTimer
    interval: 2500
    onTriggered: { root.refreshStatus = "idle"; root.refreshMessage = "" }
  }

  Component.onCompleted: {
    // Не спавнити python-луп даремно, якщо GenshinWidget вимкнено
    if (Config.enableGenshinMonitor) proc.running = true
  }
}
