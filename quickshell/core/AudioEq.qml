// ============================================================
// core/AudioEq.qml — справжній еквалайзер на PipeWire:
// module-ladspa-sink з mbeq_1197 створює віртуальний sink
// SELFshell_EQ, смуги змінюються live через pw-cli set-param.
// Увімкнення = load модуля + перемикання default sink + перенос
// активних потоків; вимкнення = все у зворотному порядку.
// Стан — data/eq.json. Після рестарту шелла стан відновлюється:
//   - sink ще живий (рестартувався тільки шелл) → адопція без
//     повторного load (інакше — дубль sink в output devices)
//   - sink мертвий (рестартувався PipeWire) + enabled:true у файлі
//     → повний ланцюг увімкнення автоматично
// ============================================================
import Quickshell.Io
import QtQuick
import "../scripts/EqPresets.js" as EqPresets

Item {
  id: root
  visible: false

  readonly property string sinkName: "SELFshell_EQ"
  readonly property string pluginPath: "/usr/lib/ladspa/mbeq_1197.so"
  // Порт-назви mbeq_1197 (порядок = control 0..14, див. analyseplugin)
  readonly property var portNames: [
    "50Hz gain (low shelving)", "100Hz gain", "156Hz gain", "220Hz gain",
    "311Hz gain", "440Hz gain", "622Hz gain", "880Hz gain", "1250Hz gain",
    "1750Hz gain", "2500Hz gain", "3500Hz gain", "5000Hz gain",
    "10000Hz gain", "20000Hz gain"
  ]
  readonly property int bandCount: 15

  // Стан (джерело правди для UI)
  property bool pluginInstalled: true
  property bool enabled: false
  property bool busy: false
  property var bands: []          // 15 значень dB (−12..+12 для UI)
  property string preset: "Flat"
  property string error: ""       // текст останнього збою ланцюга (для UI)
  // Користувацькі пресети {name: [15 gains]} та видалені вбудовані
  property var userPresets: ({})
  property var deletedBuiltins: ([])

  // внутрішнє
  property string _moduleId: ""   // індекс завантаженого модуля
  property string _savedSink: ""  // попередній default sink
  property int _eqNodeId: -1      // pw-node id для set-param
  property bool _applyingAll: false
  property bool _restoreEnabled: false
  // стан файлу прочитано? до цього saveState заблокований (інакше
  // порожній стан перезаписував файл і стирав збережений пресет)
  property bool _stateLoaded: false
  property bool _dumpDone: false

  Component.onCompleted: {
    _pluginCheck.reload()
    _stateReady()
    _stateFile.reload()
  }

  // Ланцюг ініціалізації: читаємо eq.json (async) → і лише потім dump
  // (адопція/відновлення мають знати preset/bands/enabled з файлу)
  function _stateReady() {
    _loadState()
    if (root._dumpDone) return
    root._dumpDone = true
    _dumpProc.running = true
  }

  function _flatBands() {
    var b = []
    for (var i = 0; i < bandCount; i++) b.push(0)
    return b
  }

  function _loadState() {
    var d
    try { d = JSON.parse(_stateFile.text() || "{}") } catch (e) { d = {} }
    if (!d || typeof d !== "object") d = {}
    if (d.bands && d.bands.length === bandCount) {
      // кламп: у файлі могли лишитись неклемповані значення пресетів
      bands = d.bands.map(v => Math.max(-12, Math.min(12, v)))
    } else {
      bands = _flatBands()
    }
    preset = d.preset || "Flat"
    userPresets = (d.userPresets && typeof d.userPresets === "object") ? d.userPresets : {}
    deletedBuiltins = (d.deletedBuiltins && d.deletedBuiltins.length !== undefined) ? d.deletedBuiltins : []
    _restoreEnabled = d.enabled === true
    _stateLoaded = true
    // файл міг дочитатись пізніше за адопцію — перезастосовуємо смуги
    if (enabled && _eqNodeId > 0) _applyAllNow()
  }

  function saveState() {
    if (!root._stateLoaded) return
    _stateFile.setText(JSON.stringify({
      enabled: enabled, preset: preset, bands: bands,
      userPresets: userPresets, deletedBuiltins: deletedBuiltins
    }))
  }

  function setBand(i, value) {
    var b = bands.slice()
    b[i] = Math.max(-12, Math.min(12, value))
    bands = b
    preset = "Custom"
    if (enabled && _eqNodeId > 0) {
      var entries = [portNames[i], bands[i]]
      _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
        JSON.stringify({ params: entries })]
      _setParamProc.running = true
    }
    saveState()
  }

  function applyPreset(name) {
    var gains
    if (userPresets[name] !== undefined) {
      gains = userPresets[name]
    } else {
      var all = EqPresets.all()
      if (!all[name]) return
      gains = all[name]
    }
    preset = name
    // кламп у діапазон UI: частина Winamp-пресетів (Full Treble) має
    // значення понад +12 — неклемповані смуги виїжджали за трек слайдера
    bands = []
    for (var j = 0; j < gains.length && j < bandCount; j++)
      bands.push(Math.max(-12, Math.min(12, gains[j])))
    if (enabled && _eqNodeId > 0) {
      var entries = []
      for (var i = 0; i < bandCount; i++)
        entries.push(portNames[i], bands[i])
      _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
        JSON.stringify({ params: entries })]
      _setParamProc.running = true
    }
    saveState()
  }

  function saveUserPreset(name) {
    name = (name || "").trim()
    if (name === "") return
    var u = Object.assign({}, userPresets)
    u[name] = bands.slice()
    userPresets = u
    preset = name
    saveState()
  }

  function deletePreset(name) {
    if (name === "Custom") return
    if (userPresets[name] !== undefined) {
      var u = Object.assign({}, userPresets)
      delete u[name]
      userPresets = u
    } else if (EqPresets.all()[name] !== undefined &&
               deletedBuiltins.indexOf(name) === -1) {
      deletedBuiltins = deletedBuiltins.concat([name])
    } else {
      return
    }
    if (preset === name) preset = "Custom"
    saveState()
  }

  function restoreBuiltins() {
    deletedBuiltins = []
    saveState()
  }

  function enable() {
    if (busy || enabled || !pluginInstalled) return
    error = ""
    busy = true
    _getDefaultSinkProc.running = true
  }

  function disable() {
    if (busy || !enabled) return
    error = ""
    busy = true
    // Резолв fallback-у: 1) збережений sink з моменту увімкнення (якщо
    // досі існує), 2) перший RUNNING не-EQ, 3) перший не-EQ. Без цього
    // fallback'ом ставав перший зі списку — мертвий S/PDIF-вихід.
    _disableProc.command = ["bash", "-c",
      "SAVED='" + _savedSink + "'; " +
      "T=''; " +
      "if [ -n \"$SAVED\" ] && pactl list short sinks | grep -q \"$SAVED\"; then " +
      "T=$(pactl list short sinks | grep \"$SAVED\" | head -1 | cut -f1); fi; " +
      "if [ -z \"$T\" ]; then T=$(pactl list short sinks | grep -v " + sinkName + " | grep RUNNING | head -1 | cut -f1); fi; " +
      "if [ -z \"$T\" ]; then T=$(pactl list short sinks | grep -v " + sinkName + " | head -1 | cut -f1); fi; " +
      "[ -z \"$T\" ] && exit 0; " +
      "pactl list short sink-inputs | cut -f1 | xargs -r -n1 -I{} pactl move-sink-input {} \"$T\"; " +
      "pactl set-default-sink \"$T\""]
    _disableProc.running = true
  }

  // ---------- ланцюг увімкнення ----------
  Process {
    id: _getDefaultSinkProc
    command: ["pactl", "get-default-sink"]
    stdout: StdioCollector {
      onStreamFinished: {
        root._savedSink = text.trim()
        _loadProc.command = ["pactl", "load-module", "module-ladspa-sink",
          "sink_name=" + root.sinkName,
          "plugin=" + root.pluginPath,
          "label=mbeq",
          "control=" + Array(root.bandCount).fill(0).join(",")]
        _loadProc.running = true
      }
    }
  }

  Process {
    id: _loadProc
    stdout: StdioCollector {
      id: _loadCollector
      onStreamFinished: {
        root._moduleId = text.trim()
        _setSinkProc.running = true
      }
    }
    onExited: (code) => {
      if (code !== 0) {
        root.error = "failed to load EQ sink"
        root.busy = false
      }
    }
  }

  Process {
    id: _setSinkProc
    command: ["pactl", "set-default-sink", root.sinkName]
    onExited: (code) => {
      if (code !== 0) {
        root.error = "failed to switch default sink"
        root.busy = false
        return
      }
      // активні потоки лишились на старому sink — переносимо в EQ
      _moveInputsOnProc.command = ["bash", "-c",
        "pactl list short sink-inputs | awk '{print $1}' | " +
        "xargs -r -n1 -I{} pactl move-sink-input {} " + root.sinkName]
      _moveInputsOnProc.running = true
    }
  }

  Process {
    id: _moveInputsOnProc
    onExited: { root._applyingAll = true; _findNodeProc.running = true }
  }

  // ---------- пошук pw-node id + адопція/відновлення ----------
  Process {
    id: _dumpProc
    command: ["pw-dump"]
    stdout: StdioCollector {
      onStreamFinished: root._onDump(text)
    }
  }

  Process {
    id: _findNodeProc
    command: ["pw-dump"]
    stdout: StdioCollector {
      onStreamFinished: root._onDump(text)
    }
  }

  function _onDump(text) {
    var sinkExists = false
    try {
      var objs = JSON.parse(text)
      for (var i = 0; i < objs.length; i++) {
        var o = objs[i]
        if ((o.type || "").endsWith("Node") &&
            ((o.info || {}).props || {})["node.name"] === root.sinkName) {
          sinkExists = true
          root._eqNodeId = o.id
          break
        }
      }
    } catch (e) {}

    if (sinkExists) {
      // адопція: модуль уже в PipeWire — лише приймаємо стан
      root.enabled = true
      root.busy = false
      _modulesProc.stage = "adopt"
      _modulesProc.running = true
      root._applyAllNow()
      root.saveState()
      return
    }

    if (root._restoreEnabled && !root.busy) {
      // sink мертвий (рестарт PipeWire), але стан був увімкнений
      root._restoreEnabled = false
      root.enable()
      return
    }
    // звичайний вхід із _moveInputsOnProc (свіже увімкнення)
    if (root._eqNodeId > 0) root._applyAllNow()
  }

  function _applyAllNow() {
    var entries = []
    for (var i = 0; i < bandCount; i++)
      entries.push(portNames[i], bands[i])
    _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
      JSON.stringify({ params: entries })]
    _setParamProc.running = true
  }

  // ---------- індекс модуля + вимкнення ----------
  Process {
    id: _modulesProc
    property string stage: "" // "adopt" | "disable"
    command: ["pactl", "list", "short", "modules"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].indexOf("module-ladspa-sink") !== -1 &&
              lines[i].indexOf("sink_name=" + root.sinkName) !== -1) {
            root._moduleId = lines[i].split("\t")[0]
            break
          }
        }
        if (_modulesProc.stage === "disable") {
          _modulesProc.stage = ""
          if (root._moduleId !== "") {
            _unloadProc.command = ["pactl", "unload-module", root._moduleId]
            _unloadProc.running = true
          } else {
            // модуль і так зник (рестарт PipeWire) — просто скидаємо стан
            root._eqNodeId = -1
            root.enabled = false
            root.busy = false
            root.saveState()
          }
        }
      }
    }
  }

  // ---------- вимкнення ----------
  Process {
    id: _disableProc
    onExited: {
      _modulesProc.stage = "disable"
      _modulesProc.running = true
    }
  }

  Process {
    id: _unloadProc
    onExited: {
      root._moduleId = ""
      root._eqNodeId = -1
      root.enabled = false
      root.busy = false
      root.saveState()
    }
  }

  // ---------- виконавці ----------
  Process {
    id: _setParamProc
    onExited: {
      running = false
      if (root._applyingAll) {
        root._applyingAll = false
        root.enabled = true
        root.busy = false
        root.saveState()
      }
    }
  }

  // ---------- файли ----------
  FileView {
    id: _pluginCheck
    path: "file://" + root.pluginPath
    watchChanges: false
    onLoaded: root.pluginInstalled = true
    onLoadFailed: root.pluginInstalled = false
  }

  FileView {
    id: _stateFile
    path: Qt.resolvedUrl("../data/eq.json")
    watchChanges: false
    onFileChanged: this.reload()
    onDataChanged: root._stateReady()
    onLoadFailed: root._stateReady()
  }
}
