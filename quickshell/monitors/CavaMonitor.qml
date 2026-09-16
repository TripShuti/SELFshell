// ============================================================
// quickshell/monitors/CavaMonitor.qml — аудіо-візуалізатор (cava)
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
      // Кап у 5 швидких спроб: якщо cava зламаний, далі пробує повільний
      // таймер раз на хвилину (див. нижче), а не вічний цикл падінь
      if (root.monitorEnabled && root.active) {
        if (root._restarts < 5) cavaRestartTimer.restart()
        else slowRetryTimer.restart()
      }
    }
  }

  property int _restarts: 0

  Timer {
    id: cavaRestartTimer
    interval: 2000
    // Перевіряємо заново: за 2с попап могли закрити або віджет вимкнути —
    // без гарда cava стартував би прихованим і палив CPU
    onTriggered: {
      if (root.monitorEnabled && root.active && !cavaProcess.running) {
        if (root._restarts < 5) {
          root._restarts++
          cavaProcess.running = true
        } else {
          slowRetryTimer.restart()
        }
      }
    }
  }

  // Після 5 швидких падінь — не мремо мовчки, а пробуємо раз на хвилину:
  // cava міг впасти через тимчасовий глюк PipeWire
  Timer {
    id: slowRetryTimer
    interval: 60000
    onTriggered: {
      if (root.monitorEnabled && root.active && !cavaProcess.running) {
        root._restarts = 0
        cavaProcess.running = true
      }
    }
  }

  property bool monitorEnabled: appConfig ? appConfig.cfg.mprisEnabled : false
  // Активний коли візуалізатор реально видно: віджет панелі під час
  // відтворення або відкритий попап (керується з Bar.qml) — інакше cava
  // на 30 fps спалював би CPU вхолосту весь день
  property bool active: false

  function _updateRunning() {
    if (root.monitorEnabled && root.active) {
      // скидаємо лічильник щоб після ручного re-enable був свіжий ліміт 5
      if (root._restarts >= 5) root._restarts = 0
    } else {
      cavaRestartTimer.stop()
      slowRetryTimer.stop()
    }
    cavaProcess.running = root.monitorEnabled && root.active
  }

  onMonitorEnabledChanged: _updateRunning()
  onActiveChanged: _updateRunning()
}
