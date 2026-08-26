// ============================================================
// core/AudioEq.qml — справжній еквалайзер на PipeWire:
// module-ladspa-sink з mbeq_1197 створює віртуальний sink
// SELFshell_EQ, смуги змінюються live через pw-cli set-param.
// Увімкнення = load модуля + перемикання default sink + перенос
// активних потоків; вимкнення = все у зворотному порядку.
// Стан — data/eq.json (enabled навмисно не відновлюється: модуль
// живе в PipeWire і гине після його рестарту).
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

  // внутрішнє
  property string _moduleId: ""   // індекс завантаженого модуля
  property string _savedSink: ""  // попередній default sink
  property int _eqNodeId: -1      // pw-node id для set-param
  property bool _applyingAll: false

  Component.onCompleted: {
    _pluginCheck.reload()
    _loadState()
  }

  function _flatBands() {
    var b = []
    for (var i = 0; i < bandCount; i++) b.push(0)
    return b
  }

  function _loadState() {
    try {
      var d = JSON.parse(_stateFile.text() || "{}")
      bands = (d.bands && d.bands.length === bandCount) ? d.bands : _flatBands()
      preset = d.preset || "Flat"
    } catch (e) {
      bands = _flatBands()
    }
  }

  function saveState() {
    _stateFile.setText(JSON.stringify({ preset: preset, bands: bands }))
  }

  function setBand(i, value) {
    var b = bands.slice()
    b[i] = value
    bands = b
    preset = "Custom"
    if (enabled && _eqNodeId > 0) {
      var entries = [portNames[i], value]
      _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
        JSON.stringify({ params: entries })]
      _setParamProc.running = true
    }
    saveState()
  }

  function applyPreset(name) {
    var all = EqPresets.all()
    if (!all[name]) return
    preset = name
    bands = all[name].slice()
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

  function enable() {
    if (busy || enabled || !pluginInstalled) return
    busy = true
    _getDefaultSinkProc.running = true
  }

  function disable() {
    if (busy || !enabled) return
    busy = true
    // спочатку повертаємо потоки на попередній sink, потім сам sink, потім модуль
    _moveInputsProc.command = ["bash", "-c",
      "pactl list short sink-inputs | awk '{print $1}' | " +
      "xargs -r -n1 -I{} pactl move-sink-input {} " + _savedSink]
    _moveInputsProc.running = true
  }

  // ---------- ланцюг увімкнення ----------
  Process {
    id: _getDefaultSinkProc
    command: ["pactl", "get-default-sink"]
    stdout: StdioCollector {
      onStreamFinished: {
        root._savedSink = text.trim()
        root._loadProc.running = true
      }
    }
  }

  Process {
    id: _loadProc
    stdout: StdioCollector {
      id: _loadCollector
      onStreamFinished: {
        root._moduleId = text.trim()
        root._setSinkProc.running = true
      }
    }
    onExited: (code) => { if (code !== 0) root.busy = false }
  }

  Process {
    id: _setSinkProc
    command: ["pactl", "set-default-sink", root.sinkName]
    onExited: (code) => {
      if (code !== 0) { root.busy = false; return }
      // активні потоки лишились на старому sink — переносимо в EQ
      _moveInputsOnProc.command = ["bash", "-c",
        "pactl list short sink-inputs | awk '{print $1}' | " +
        "xargs -r -n1 -I{} pactl move-sink-input {} " + root.sinkName]
      _moveInputsOnProc.running = true
    }
  }

  Process {
    id: _moveInputsOnProc
    onExited: { root._applyingAll = true; root._findNodeProc.running = true }
  }

  // ---------- пошук pw-node id для set-param ----------
  Process {
    id: _findNodeProc
    command: ["pw-dump"]
    stdout: StdioCollector {
      onStreamFinished: {
        // pw-dump віддає цілісний JSON-масив (не JSON-lines)
        try {
          var objs = JSON.parse(text)
          for (var i = 0; i < objs.length; i++) {
            var o = objs[i]
            if ((o.type || "").endsWith("Node") &&
                ((o.info || {}).props || {})["node.name"] === root.sinkName) {
              root._eqNodeId = o.id
              break
            }
          }
        } catch (e) {}
        // sink стартує з нульовими смугами — застосовуємо збережені
        root._applyAllNow()
      }
    }
  }

  function _applyAllNow() {
    var entries = []
    for (var i = 0; i < bandCount; i++)
      entries.push(portNames[i], bands[i])
    _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
      JSON.stringify({ params: entries })]
    _setParamProc.running = true
  }

  // ---------- вимкнення ----------
  Process {
    id: _moveInputsProc
    onExited: {
      _restoreSinkProc.command = ["pactl", "set-default-sink", root._savedSink]
      _restoreSinkProc.running = true
    }
  }

  Process {
    id: _restoreSinkProc
    onExited: {
      _unloadProc.command = ["pactl", "unload-module", root._moduleId]
      _unloadProc.running = true
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
  }
}
