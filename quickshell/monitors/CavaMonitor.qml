// ============================================================
// CavaMonitor.qml — аудіо-візуалізатор (cava)
// ============================================================
import Quickshell.Io
import QtQuick

// Монітор аудіо-візуалізації — читає дані з cava та згладжує
Item {
  id: root

  required property QtObject appConfig

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
    command: ["stdbuf", "-oL", "cava", "-p",
      Qt.resolvedUrl("../services/cava-vis.conf").toString().replace("file://", "")]
    stdout: lineParser

    onStarted: root._restarts = 0
    onExited: {
      // cava впав (глюк аудіо тощо) — перезапускаємось, поки ще потрібен.
      // Кап у 5 спроб: якщо cava зламаний (немає пакета тощо), не крутимо
      // цикл падіння-рестарту вічно
      if (root.monitorEnabled && root.active && root._restarts < 5) {
        root._restarts++
        cavaRestartTimer.restart()
      }
    }
  }

  property int _restarts: 0

  Timer {
    id: cavaRestartTimer
    interval: 2000
    onTriggered: cavaProcess.running = true
  }

  property bool monitorEnabled: appConfig ? appConfig.cfg.mprisEnabled : false
  // Активний коли візуалізатор реально видно: віджет панелі під час
  // відтворення або відкритий попап (керується з Bar.qml) — інакше cava
  // на 30 fps спалював би CPU вхолосту весь день
  property bool active: false

  function _updateRunning() {
    cavaProcess.running = root.monitorEnabled && root.active
  }

  onMonitorEnabledChanged: _updateRunning()
  onActiveChanged: _updateRunning()
}
