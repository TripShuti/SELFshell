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

  readonly property string script: "$HOME/.config/quickshell/scripts/tracklist.py"

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

  // --- Логіка ---

  function refresh() {
    if (!root.active || root.playerName === "") {
      root.trackIds = []
      root.tracks = []
      root.supported = false
      root.loading = false
      return
    }
    root.loading = true
    listProc.command = ["sh", "-c",
      "python3 " + root.script + " --player " + root.playerName + " list"]
    listProc.running = true
  }

  // Запитує метадані ВСІХ треків — плейліст скролиться повністю
  function _fetchAll() {
    if (root.trackIds.length === 0) {
      root.tracks = []
      root.loading = false
      return
    }

    metaProc.command = ["sh", "-c",
      "python3 " + root.script + " --player " + root.playerName +
      " metadata " + root.trackIds.join(" ")]
    metaProc.running = true
  }

  function goTo(trackId) {
    if (trackId === "" || trackId === undefined || trackId === null) return
    gotoProc.command = ["sh", "-c",
      "python3 " + root.script + " --player " + root.playerName +
      " goto " + trackId]
    gotoProc.running = true
  }

  // Оновлення при зміні плеєра чи активності
  onActiveChanged: refresh()
  onPlayerNameChanged: refresh()
}
