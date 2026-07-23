// ============================================================
// CavaMonitor.qml — аудіо-візуалізатор (cava)
// ============================================================
import Quickshell.Io
import "../Config.js" as Config
import QtQuick

// Монітор аудіо-візуалізації — читає дані з cava та згладжує
Item {
  id: root

  readonly property int barCount: 28
  property var bars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
  property var _smooth: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

  // Парсить рядки з cava (роздільник ";")
  SplitParser {
    id: lineParser
    splitMarker: "\n"

    onRead: data => {
      var text = (data ?? "").trim()
      if (text.length === 0) return
      var parts = text.split(";")
      if (parts.length < root.barCount) return

      // Експоненційне згладжування
      var arr = root._smooth
      for (var i = 0; i < root.barCount; ++i) {
        var v = parseInt(parts[i])
        var raw = isFinite(v) ? Math.min(v / 1000, 1) : 0
        arr[i] = arr[i] * 0.55 + raw * 0.45
      }
      root._smooth = arr
      root.bars = arr.slice()
    }
  }

  // Процес cava з конфігом
  Process {
    id: cavaProcess
    command: ["sh", "-c", "stdbuf -oL cava -p $HOME/.config/quickshell/cava-vis.conf"]
    stdout: lineParser
  }

  Component.onCompleted: {
    // Не спавнити cava даремно, якщо MprisWidget (єдиний споживач цих даних) вимкнено
    if (Config.enableCavaMonitor) cavaProcess.running = true
  }
}
