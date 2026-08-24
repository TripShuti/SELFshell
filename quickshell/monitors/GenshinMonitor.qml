// ============================================================
// GenshinMonitor.qml — монітор Genshin Impact: поллінг HoYoLAB
// API, локальний обрахунок смоли, чекін
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  required property QtObject appConfig

  property string resinText: "\uF737 0/200"
  property string tooltip: "Loading..."
  property string resinClass: "normal"

  property string refreshStatus: "idle"
  property string refreshMessage: ""

  property int _lastSyncResin: 0
  property int _lastSyncMaxResin: 200
  property real _lastSyncTime: 0
  property string _lastSyncDate: ""
  property bool _reachedMaxToday: false
  property bool _firstSyncDone: false

  readonly property string _basePath: Qt.resolvedUrl("../scripts/genshin_stats.py").toString().replace("file://", "")

  function _todayStr() {
    // локальна дата (не UTC): UTC давав вчорашній день у перші години
    // доби для східних поясів і ламав порівняння щоденного синку
    var d = new Date()
    return d.getFullYear() + "-" +
      String(d.getMonth() + 1).padStart(2, "0") + "-" +
      String(d.getDate()).padStart(2, "0")
  }

  function _currentResin() {
    if (_lastSyncTime === 0) return 0
    var elapsed = (Date.now() / 1000) - _lastSyncTime
    return Math.min(_lastSyncMaxResin, _lastSyncResin + Math.floor(elapsed / 480))
  }

  function _updateDisplay() {
    var resin = _currentResin()
    root.resinText = " " + resin + "/" + _lastSyncMaxResin
    root.resinClass = resin >= 190 ? "critical" : "normal"
  }

  // Через скільки секунд після досягнення капу знову дозволяємо перевіряти
  // (щоб не залипати на "200/200" увесь день, якщо гравець витратив смолу)
  readonly property int _maxFreezeTimeout: 2400 // 40 хв

  function _checkHighResin() {
    if (!_firstSyncDone) {
      highResinTimer.running = false
      return
    }
    if (_reachedMaxToday) {
      if ((Date.now() / 1000 - _lastSyncTime) > _maxFreezeTimeout)
        _reachedMaxToday = false
      else {
        highResinTimer.running = false
        return
      }
    }
    highResinTimer.running = _currentResin() >= 198
  }

  function _checkDailySync() {
    if (!_firstSyncDone) return
    var now = new Date()
    if (now.getHours() >= 7 && _lastSyncDate !== _todayStr())
      _doSync()
  }

  function _parseSyncResult(obj) {
    if (typeof obj !== "object" || obj === null) return
    root.resinText = obj.text ?? root.resinText
    root.tooltip = obj.tooltip ?? root.tooltip
    root.resinClass = obj.class ?? root.resinClass

    if (obj.resin !== undefined && obj.ok !== false) {
      root._lastSyncResin = obj.resin
      root._lastSyncMaxResin = obj.maxResin ?? 200
      root._lastSyncTime = Date.now() / 1000
      root._lastSyncDate = root._todayStr()
      root._firstSyncDone = true

      // Кап рахуємо від реального максимуму, не від захардкодженого 200
      if (obj.resin >= root._lastSyncMaxResin) {
        root._reachedMaxToday = true
        highResinTimer.running = false
      } else {
        root._reachedMaxToday = false
        root._checkHighResin()
      }
    }

    // Таймери працюють тільки поки монітор увімкнений — вимкнення під час
    // активного синку не повинно запустити їх заднім числом
    if (!mainTimer.running && root.monitorEnabled) mainTimer.running = true
  }

  function _doSync() {
    if (!root.monitorEnabled) return
    if (syncProc.running) return
    root._syncManual = false
    console.log("[Genshin] Starting sync at", new Date().toISOString())
    syncProc.running = true
  }

  // Мінімальний інтервал між ручними рефрешами (сек), захист від спам-кліків
  readonly property int _manualRefreshCooldown: 30

  function refreshNow() {
    if (!root.monitorEnabled) return
    if (syncProc.running) return
    if (_firstSyncDone && (Date.now() / 1000 - _lastSyncTime) < _manualRefreshCooldown) {
      root.refreshStatus = "error"
      root.refreshMessage = "Wait a bit, synced recently"
      resetTimer.restart()
      return
    }
    root.refreshStatus = "loading"
    root.refreshMessage = ""
    root._syncManual = true
    syncProc.running = true
  }

  // Старт: перший синк — але ПІСЛЯ завантаження config.json (async):
  // в onCompleted cfg ще дефолтний (genshinEnabled=true), і синк стріляв
  // би навіть для вимкненого віджета. onMonitorEnabledChanged нижче
  // покриває і пізніше ввімкнення
  Timer {
    interval: 1500
    running: true
    repeat: false
    onTriggered: if (root.monitorEnabled && !root._firstSyncDone) _doSync()
  }

  // Головний таймер: локальний обрахунок + тригери
  Timer {
    id: mainTimer
    interval: 60000
    running: false
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      _checkDailySync()
      _checkHighResin()
      _updateDisplay()
    }
  }

  // Таймер високої смоли: автоматичний синк кожні 8 хв (180+)
  Timer {
    id: highResinTimer
    interval: 480000
    running: false
    repeat: true
    onTriggered: { if (!syncProc.running) syncProc.running = true }
  }

  // Єдиний процес синку (фоновий і ручний рефреш):
  // _syncManual розрізняє джерело запуску в onExited
  property bool _syncManual: false

  Process {
    id: syncProc
    property string _buf: ""
    command: ["python3", root._basePath, "sync"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => { syncProc._buf += (data ?? "") }
    }
    onExited: (code) => {
      running = false
      var text = syncProc._buf.trim()
      syncProc._buf = ""

      // Ручний рефреш має власний фідбек (статус/повідомлення)
      if (root._syncManual) {
        root._syncManual = false
        if (code !== 0 && root.refreshStatus === "loading") {
          root.refreshStatus = "error"
          root.refreshMessage = "Launch error"
          resetTimer.restart()
          return
        }
        if (text === "") {
          root.refreshStatus = "error"
          root.refreshMessage = "Empty response"
          resetTimer.restart()
          return
        }
        try {
          root._parseSyncResult(JSON.parse(text))
          root.refreshStatus = "ok"
          root.refreshMessage = "Updated"
          resetTimer.restart()
        } catch (e) {
          console.error("Manual error:", e)
          root.refreshStatus = "error"
          root.refreshMessage = "Error: " + e
          resetTimer.restart()
        }
        return
      }

      if (text === "") return
      try {
        root._parseSyncResult(JSON.parse(text))
        console.log("[Genshin] Sync done, resin:", root._lastSyncResin, "/", root._lastSyncMaxResin)
      }
      catch (e) { console.error("Sync error:", e) }
    }
  }

  // Скидання статусу рефрешу через 2.5 с
  Timer {
    id: resetTimer
    interval: 2500
    onTriggered: { root.refreshStatus = "idle"; root.refreshMessage = "" }
  }

  property bool monitorEnabled: appConfig ? appConfig.cfg.genshinEnabled : false
  onMonitorEnabledChanged: {
    if (monitorEnabled) _doSync()
    else {
      mainTimer.running = false
      highResinTimer.running = false
      syncProc.running = false
    }
  }
}