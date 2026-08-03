// ============================================================
// TrackListService.qml — сервіс MPRIS TrackList: список треків
// через scripts/tracklist.py (обгортка D-Bus TrackList)
// ============================================================
import Quickshell.Io
import QtQuick

Item {
  id: root
  visible: false

  // Ім'я плеєра (як в identity, lowercased) — ставиться ззовні
  property string playerName: ""
  property bool supported: false
  property var trackIds: []
  property var tracks: []
  property bool loading: false
  property bool active: false

  readonly property string script: Qt.resolvedUrl("../scripts/tracklist.py").toString().replace("file://", "")
  // Розв'язане D-Bus ім'я плеєра (може відрізнятись від identity, напр.
  // chromium.instance1172) — отримується від tracklist.py busname.
  property string _resolvedBusName: ""

  // --- Процеси ---

  Process {
    id: listProc

    stdout: StdioCollector {
      id: listCollector
      waitForEnd: true
      onStreamFinished: {
        var text = listCollector.text.trim()
        if (!text) {
          root.trackIds = []
          root.tracks = []
          root.supported = false
          root.loading = false
          return
        }
        try {
          var ids = JSON.parse(text)
          // Список не змінився — не перезавантажуємо метадані,
          // інакше модель заміниться і скинеться скрол плейлісту
          if (JSON.stringify(ids) === JSON.stringify(root.trackIds)) {
            root.loading = false
            return
          }
          root.trackIds = ids
          root.supported = true
          root._fetchAll()
        } catch (e) {
          console.warn("TrackListService: не вдалось розпарсити список треків", e)
          root.trackIds = []
          root.supported = false
          root.loading = false
        }
      }
    }
  }

  Process {
    id: metaProc

    stdout: StdioCollector {
      id: metaCollector
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        var text = metaCollector.text.trim()
        if (!text) return
        try {
          root.tracks = JSON.parse(text)
        } catch (e) {
          console.warn("TrackListService: не вдалось розпарсити метадані треків", e)
          root.tracks = []
        }
        root.loading = false
      }
    }
  }

  Process {
    id: gotoProc
    onExited: running = false
  }

  // Отримує розв'язане D-Bus ім'я плеєра — dbus-monitor слухає саме його.
  // Запускається перед стартом watch, при зміні плеєра.
  Process {
    id: busnameProc

    stdout: StdioCollector {
      id: busnameCollector
      waitForEnd: true
      onStreamFinished: {
        var text = busnameCollector.text.trim()
        // Плеєр недоступний/вмер — лишаємо старе ім'я; _startWatch
        // підставиться з фолбеком через _playerBusName()
        if (text) root._resolvedBusName = text
        root._startWatch()
      }
    }
  }

  // Спостерігач за сигналами TrackList від плеєра (dbus-monitor | grep,
  // як у sleepMonitor в shell.qml). Дає миттєве оновлення списку замість
  // чекання 20-секундного поллу. Полл лишається страховкою.
  Process {
    id: watchProc

    // SplitParser не накопичує вивід — кожен рядок це окремий сигнал
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: _signalDebounce.restart()
    }

    onExited: {
      // dbus-monitor помер (глюк D-Bus тощо) — перезапускаємось,
      // поки спостерігач ще потрібен
      if (root.active && root.supported && root.playerName !== "")
        watchRestartTimer.restart()
    }
  }

  Timer {
    id: watchRestartTimer
    interval: 3000
    onTriggered: root._startWatch()
  }

  Timer {
    id: _signalDebounce
    interval: 500
    onTriggered: root.refresh()
  }

  // --- Логіка ---

  function refresh() {
    if (!root.active || root.playerName === "") {
      root.trackIds = []
      root.tracks = []
      root.supported = false
      root.loading = false
      return
    }
    // Запит уже виконується — не запускаємо другий паралельний процес
    // (гонка за порядок результатів)
    if (listProc.running) return
    root.loading = true
    // Прямі аргументи, без sh -c: playerName не парситься шеллом
    listProc.command = ["python3", root.script, "--player", root.playerName, "list"]
    listProc.running = true
  }

  // Запитує метадані ВСІХ треків — плейліст скролиться повністю
  function _fetchAll() {
    if (root.trackIds.length === 0) {
      root.tracks = []
      root.loading = false
      return
    }
    if (metaProc.running) return
    metaProc.command = ["python3", root.script, "--player", root.playerName,
      "metadata"].concat(root.trackIds)
    metaProc.running = true
  }

  function goTo(trackId) {
    if (trackId === "" || trackId === undefined || trackId === null) return
    gotoProc.command = ["python3", root.script, "--player", root.playerName,
      "goto", trackId]
    gotoProc.running = true
  }

  // D-Bus ім'я плеєра: identity може бути без префікса "org.mpris.MediaPlayer2."
  // Точний резолв (включно з незбіжними іменами на кшталт chromium.instance1172)
  // робить tracklist.py busname; тут — синхронний фолбек для першого запуску.
  function _playerBusName() {
    if (root.playerName.startsWith("org.mpris.MediaPlayer2.")) return root.playerName
    return "org.mpris.MediaPlayer2." + root.playerName
  }

  function _startWatch() {
    if (!root.active || !root.supported || root.playerName === "") return
    watchRestartTimer.stop()
    watchProc.running = false
    var bus = root._resolvedBusName !== "" ? root._resolvedBusName : root._playerBusName()
    watchProc.command = ["sh", "-c",
      "dbus-monitor --session \"type=signal,sender=" + bus +
      ",interface=org.mpris.MediaPlayer2.TrackList\" 2>/dev/null "
      + "| grep --line-buffered -E 'TrackListReplaced|TrackAdded|TrackRemoved'"]
    watchProc.running = true
  }

  function _stopWatch() {
    watchRestartTimer.stop()
    watchProc.running = false
  }

  // Резолв bus name перед стартом спостерігача — щоб dbus-monitor слухав
  // правильний sender навіть коли identity не збігається з well-known ім'ям.
  function _resolveBusName() {
    if (!root.active || !root.supported || root.playerName === "") return
    if (root.playerName.startsWith(":")) {
      root._resolvedBusName = root.playerName
      root._startWatch()
      return
    }
    busnameProc.command = ["python3", root.script, "--player", root.playerName, "busname"]
    busnameProc.running = true
  }

  // Оновлення при зміні плеєра чи активності
  onActiveChanged: {
    refresh()
    if (root.active)
      root._resolveBusName()
    else
      root._stopWatch()
  }
  onPlayerNameChanged: {
    root._resolvedBusName = ""
    refresh()
    if (root.active)
      root._resolveBusName()
  }
  onSupportedChanged: {
    if (root.supported)
      root._resolveBusName()
    else
      root._stopWatch()
  }
}
