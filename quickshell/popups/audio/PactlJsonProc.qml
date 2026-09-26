// ============================================================
// quickshell/popups/audio/PactlJsonProc.qml — pactl list одним документом
// ============================================================
import Quickshell.Io
import QtQuick

// `pactl -f json list <what>` → розпарсений масив. Відрізняються лише
// доставка (масив як є чи згортка в {name: obj}) та поведінка на
// порожньому/битому виводі (скинути модель чи лишити стару — щоб
// транзиєнтний провал pactl не моргав мапами портів).
Process {
  id: root

  property string pactlWhat: ""
  // true — віддати масив як є; false — згорнути в {name: obj}
  property bool rawArray: true
  // true — порожній/битий вивід скидає модель; false — лишає стару
  property bool resetOnEmpty: true
  signal loaded(var data)

  command: ["pactl", "-f", "json", "list", root.pactlWhat]

  stdout: StdioCollector {
    id: collector
    waitForEnd: true
    onStreamFinished: {
      var text = collector.text.trim()
      if (!text) {
        if (root.resetOnEmpty) root.loaded(root.rawArray ? [] : ({}))
        return
      }
      try {
        var arr = JSON.parse(text)
        if (root.rawArray) {
          root.loaded(arr)
          return
        }
        var map = {}
        for (var i = 0; i < arr.length; i++) map[arr[i].name] = arr[i]
        root.loaded(map)
      } catch (e) {
        console.warn("[AudioMixer] " + root.pactlWhat + " parse fail", e)
        if (root.resetOnEmpty) root.loaded(root.rawArray ? [] : ({}))
      }
    }
  }
}
