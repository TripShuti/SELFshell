// ============================================================
// quickshell/core/AudioEq.qml — 15-смуговий еквалайзер PipeWire (filter-chain SELFshell_EQ, live pw-cli, data/eq.json)
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick
import "../scripts/EqPresets.js" as EqPresets

Item {
  id: root
  visible: false

  readonly property string sinkName: "SELFshell_EQ"
  readonly property string confPath: Quickshell.env("HOME") +
      "/.config/pipewire/pipewire.conf.d/10-selfshell-eq.conf"
  readonly property string pluginPath: "/usr/lib/ladspa/mbeq_1197.so"
  // Базові назви контрольних портів mbeq_1197 (порядок 0..14)
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
  property string error: ""       // текст останнього збою (для UI)
  // Користувацькі пресети {name: [15 gains]}, видалені вбудовані
  // та запінені (порядок масиву = порядок чипів, хронологія пінів)
  property var userPresets: ({})
  property var deletedBuiltins: ([])
  property var pinned: ([])

  // внутрішнє
  property int _eqNodeId: -1      // pw-node id EQ-sink (для set-param)
  property string _savedSink: ""  // default sink до увімкнення
  property bool _applyingAll: false
  property bool _restoreEnabled: false
  property bool _stateLoaded: false
  property bool _dumpDone: false
  property bool _confRestartPending: false

  Component.onCompleted: {
    _pluginCheck.reload()
    _stateReady()
    _stateFile.reload()
  }

  onEnabledChanged: {
    if (enabled && _eqNodeId >= 0) _relinkProc.running = true
  }

  // Ініціалізація: читаємо eq.json (async) → забезпечуємо конфіг → dump
  function _stateReady() {
    _loadState()
    if (root._dumpDone) return
    root._dumpDone = true
    _ensureConf()
    _dumpProc.running = true
  }

  function _ensureConf() {
    var content = '# SELFshell audio equalizer (managed by the shell)\n' +
      'context.modules = [\n' +
      '  {   name = libpipewire-module-filter-chain\n' +
      '      args = {\n' +
      '          node.description = "SELFshell EQ"\n' +
      '          media.name = "SELFshell EQ"\n' +
      '          filter.graph = {\n' +
      '              nodes = [\n' +
      '                  {\n' +
      '                      type = ladspa\n' +
      '                      name = mbeqL\n' +
      '                      plugin = "' + root.pluginPath + '"\n' +
      '                      label = mbeq\n' +
      '                      control = { ' + _zeroControls() + ' }\n' +
      '                  }\n' +
      '                  {\n' +
      '                      type = ladspa\n' +
      '                      name = mbeqR\n' +
      '                      plugin = "' + root.pluginPath + '"\n' +
      '                      label = mbeq\n' +
      '                      control = { ' + _zeroControls() + ' }\n' +
      '                  }\n' +
      '              ]\n' +
      '              inputs = [ "mbeqL:Input" "mbeqR:Input" ]\n' +
      '              outputs = [ "mbeqL:Output" "mbeqR:Output" ]\n' +
      '          }\n' +
      '          capture.props = {\n' +
      '              media.class = Audio/Sink\n' +
      '              node.name = "SELFshell_EQ"\n' +
      '              audio.position = [ FL, FR ]\n' +
      '          }\n' +
      '          playback.props = {\n' +
      '              audio.position = [ FL, FR ]\n' +
      '          }\n' +
      '      }\n' +
      '  }\n' +
      ']\n'
    _confFile.setText(content)
  }

  function _shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function _zeroControls() {
    var parts = []
    for (var i = 0; i < bandCount; i++)
      parts.push('"' + i + '" = 0.0')
    return parts.join(" ")
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
    // міграція Custom → Flat+bands (Custom повністю видалено)
    if (d.preset === "Custom") {
      preset = "Flat"
    } else {
      preset = d.preset || "Flat"
    }
    // прибрати Custom з pinned/deletedBuiltins якщо затесався
    var _pinned = (d.pinned && d.pinned.length !== undefined) ? d.pinned : []
    pinned = _pinned.filter(n => n !== "Custom")
    var _deleted = (d.deletedBuiltins && d.deletedBuiltins.length !== undefined) ? d.deletedBuiltins : []
    deletedBuiltins = _deleted.filter(n => n !== "Custom")
    if (d.userPresets && typeof d.userPresets === "object") {
      var _up = {}
      for (var k in d.userPresets) if (k !== "Custom") _up[k] = d.userPresets[k]
      userPresets = _up
    } else {
      userPresets = {}
    }
    _restoreEnabled = d.enabled === true
    _stateLoaded = true
    // файл міг дочитатись пізніше за адопцію — перезастосовуємо смуги
    if (enabled && _eqNodeId > 0) {
      _applyAllNow()
      _relinkProc.running = true
    }
  }

  function saveState() {
    if (!root._stateLoaded) return
    _stateFile.setText(JSON.stringify({
      enabled: enabled, preset: preset, bands: bands,
      userPresets: userPresets, deletedBuiltins: deletedBuiltins,
      pinned: pinned
    }))
  }

  // ---------- застосування смуг (live, pw-cli) ----------
  function _applyAllNow() {
    if (_eqNodeId < 0) return
    var entries = []
    for (var px = 0; px < 2; px++)
      for (var i = 0; i < bandCount; i++)
        entries.push((px === 0 ? "mbeqL:" : "mbeqR:") + portNames[i], bands[i])
    _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
      JSON.stringify({ params: entries })]
    _setParamProc.running = true
  }

  function setBand(i, value) {
    var b = bands.slice()
    b[i] = Math.max(-12, Math.min(12, value))
    bands = b
    // preset лишається як був (Techno/Flat) — Custom видалено, зміни live до рестарту
    if (enabled && _eqNodeId > 0) {
      _setParamProc.command = ["pw-cli", "s", String(_eqNodeId), "2",
        JSON.stringify({ params: [
          "mbeqL:" + portNames[i], b[i],
          "mbeqR:" + portNames[i], b[i]
        ] })]
      _setParamProc.running = true
    }
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
    if (enabled && _eqNodeId > 0) _applyAllNow()
    saveState()
  }

  // ---------- менеджмент пресетів ----------
  // Новий пресет з поточних смуг: ім'я "new", "new2", "new3"… — перше
  // вільне (не збігається з user-пресетами та вбудованими)
  function createPreset() {
    var base = "new"
    var name = base
    var n = 2
    while (userPresets[name] !== undefined || EqPresets.all()[name] !== undefined) {
      name = base + n
      n++
    }
    userPresets = Object.assign({}, userPresets, { [name]: bands.slice() })
    preset = name
    saveState()
  }

  function deletePreset(name) {
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
    if (isPinned(name)) {
      var _p = pinned.slice()
      _p.splice(_p.indexOf(name), 1)
      pinned = _p
    }
    if (preset === name) preset = "Flat"
    saveState()
  }

  // Перейменування зберігає ВЛАСНІ смуги пресета (не поточний стан EQ).
  // Built-in → user-shadow під новим ім'ям, старе ховається.
  function renamePreset(oldName, newName) {
    newName = (newName || "").trim()
    if (newName === "" || newName === oldName) return
    if (userPresets[newName] !== undefined || EqPresets.all()[newName] !== undefined) return

    var oldBands
    if (userPresets[oldName] !== undefined) {
      oldBands = userPresets[oldName]
      var u = Object.assign({}, userPresets)
      delete u[oldName]
      u[newName] = oldBands
      userPresets = u
    } else if (EqPresets.all()[oldName] !== undefined) {
      oldBands = EqPresets.all()[oldName]
      if (deletedBuiltins.indexOf(oldName) === -1)
        deletedBuiltins = deletedBuiltins.concat([oldName])
      userPresets = Object.assign({}, userPresets, { [newName]: oldBands })
    } else {
      return
    }

    var pi = pinned.indexOf(oldName)
    if (pi !== -1) {
      var p = pinned.slice()
      p[pi] = newName
      pinned = p
    }
    if (preset === oldName) preset = newName
    saveState()
  }

  function togglePin(name) {
    var pi = pinned.indexOf(name)
    if (pi !== -1) {
      var p = pinned.slice()
      p.splice(pi, 1)
      pinned = p
    } else {
      pinned = pinned.concat([name]) // кожен новий пін — за попереднім
    }
    saveState()
  }

  function isPinned(name) { return pinned.indexOf(name) !== -1 }

  // ---------- увімкнення / вимкнення (тільки роутинг) ----------
  // Перезаписати пресет поточними смугами (контекстне меню → Save
  // changes). Built-in → створюється user-shadow з тим самим ім'ям,
  // який перекриває вбудований
  function saveChangesTo(name) {
    userPresets = Object.assign({}, userPresets, { [name]: bands.slice() })
    saveState()
  }

  // чи існує чип для цього імені (не видалений, не перекритий)
  function chipExists(name) {
    if (userPresets[name] !== undefined) return true
    return EqPresets.all()[name] !== undefined && deletedBuiltins.indexOf(name) === -1
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
    // досі існує), 2) поточний default якщо не EQ, 3) перший RUNNING не-EQ,
    // 4) перший не-EQ. Без збереженого — fallback ставав мертвим S/PDIF
    var _sq = _shellQuote(root._savedSink)
    var _eqQ = _shellQuote(root.sinkName)
    _moveInputsProc.command = ["bash", "-c",
      "SAVED=" + _sq + "; " +
      "T=''; " +
      "if [ -n \"$SAVED\" ] && pactl list short sinks | grep -q \"$SAVED\"; then " +
      "T=$(pactl list short sinks | grep \"$SAVED\" | head -1 | cut -f1); fi; " +
      "if [ -z \"$T\" ]; then T=$(pactl get-default-sink); [ \"$T\" = " + _eqQ + " ] && T=''; fi; " +
      "if [ -z \"$T\" ]; then T=$(pactl list short sinks | grep -v " + _eqQ + " | grep RUNNING | head -1 | cut -f1); fi; " +
      "if [ -z \"$T\" ]; then T=$(pactl list short sinks | grep -v " + _eqQ + " | head -1 | cut -f1); fi; " +
      "[ -z \"$T\" ] && exit 0; " +
      "pactl list short sink-inputs | cut -f1 | " +
      "xargs -r -n1 -I{} pactl move-sink-input {} \"$T\"; " +
      "pactl set-default-sink \"$T\""]
    _moveInputsProc.running = true
  }

  // ---------- ланцюг увімкнення ----------
  Process {
    id: _getDefaultSinkProc
    // резолвимо sink-for-restore: поточний default, але якщо це вже EQ
    // (отруєний стан попередніх кривих спроб) — перший не-EQ RUNNING
    readonly property string _eqQuoted: "'" + root.sinkName.replace(/'/g, "'\\''") + "'"
    command: ["bash", "-c",
      "d=$(pactl get-default-sink); " +
      "if [ \"$d\" = " + _eqQuoted + " ]; then " +
      "d=$(pactl list short sinks | grep -v " + _eqQuoted + " | grep RUNNING | head -1 | cut -f1); fi; " +
      "if [ -z \"$d\" ]; then d=$(pactl list short sinks | grep -v " + _eqQuoted + " | head -1 | cut -f1); fi; " +
      "echo \"$d\""]
    stdout: StdioCollector {
      onStreamFinished: {
        root._savedSink = text.trim()
        // переносимо граючі потоки в EQ ще ДО перемикання default
        _moveInputsOnProc.command = ["bash", "-c",
          "pactl list short sink-inputs | cut -f1 | " +
          "xargs -r -n1 -I{} pactl move-sink-input {} " + root.sinkName]
        _moveInputsOnProc.running = true
      }
    }
  }

  Process {
    id: _moveInputsOnProc
    onExited: {
      // прапор: після set-param смуг enabled = true (див. _setParamProc)
      root._applyingAll = true
      _setDefaultProc.running = true
    }
  }

  Process {
    id: _setDefaultProc
    command: ["pactl", "set-default-sink", root.sinkName]
    onExited: (code) => {
      if (code !== 0) { root.error = "failed to switch default sink"; root.busy = false; return }
      _findNodeProc.running = true
    }
  }

  // ---------- пошук pw-node id EQ-sink ----------
  Process {
    id: _findNodeProc
    command: ["pw-dump"]
    stdout: StdioCollector {
      onStreamFinished: {
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
        if (root._eqNodeId < 0) {
          root.error = "EQ sink node not found"
          root.busy = false
          return
        }
        root._applyAllNow()
        // одразу перелінковуємо вихід filter-chain на актуальний хардвар
        _relinkProc.running = true
      }
    }
  }

  // ---------- вимкнення ----------
  Process {
    id: _moveInputsProc
    onExited: (code) => {
      // default повертаємо навіть якщо move впав (може, потоків не було)
      var _eqQ2 = "'" + root.sinkName.replace(/'/g, "'\\''") + "'"
      _restoreDefaultProc.command = ["bash", "-c",
        "T=$(pactl get-default-sink); " +
        "[ \"$T\" = " + _eqQ2 + " ] && " +
        "T=$(pactl list short sinks | grep -v " + _eqQ2 + " | grep RUNNING | head -1 | cut -f1); " +
        "[ \"$T\" = " + _eqQ2 + " ] && " +
        "T=$(pactl list short sinks | grep -v " + _eqQ2 + " | head -1 | cut -f1); " +
        "[ -z \"$T\" ] && exit 0; " +
        "pactl set-default-sink \"$T\""]
      _restoreDefaultProc.running = true
    }
  }

  Process {
    id: _restoreDefaultProc
    onExited: {
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

  // ---------- конфіг і перевірка наявності sink ----------
  // Якщо sink зник (конфігу не було / PipeWire без нього) — пишемо конфіг
  // і рестартимо PipeWire (одноразово, короткий дроп звуку)
  Process {
    id: _dumpProc
    command: ["pw-dump"]
    stdout: StdioCollector {
      onStreamFinished: {
        var sinkFound = false
        try {
          var objs = JSON.parse(text)
          for (var i = 0; i < objs.length; i++) {
            var o = objs[i]
            if ((o.type || "").endsWith("Node") &&
                ((o.info || {}).props || {})["node.name"] === root.sinkName) {
              sinkFound = true
              root._eqNodeId = o.id
              break
            }
          }
        } catch (e) {}

        if (sinkFound) {
          if (root._restoreEnabled && !root.busy) {
            root._restoreEnabled = false
            root.enable()
          }
          return
        }

        // sink нема → забезпечуємо конфіг; рестарт — після фактичного
        // збереження файлу (onSaved), інакше рестарт обігне запис
        if (root.pluginInstalled) {
          root._confRestartPending = true
          _ensureConf()
        }
      }
    }
  }

  Process {
    id: _pwRestartProc
    command: ["systemctl", "--user", "restart", "pipewire"]
    onExited: _reDumpTimer.start()
  }

  Timer {
    id: _reDumpTimer
    interval: 2000
    onTriggered: _dumpProc.running = true
  }

  // ---------- авто-перелінк після зміни заліза (навушники ↔ колонки) ----------
  // Перевірка та відновлення лінків EQ (output.filter-chain) після зміни аудіовиходів:
  // якщо підключено Bluetooth — лінкує ексклюзивно на нього, інакше — на всі доступні sinks.
  // Перебудовує зв'язки тільки за потреби, щоб не рвати аудіобуфер.
Timer {
    id: _linkCheckTimer
    interval: 3000
    running: root.enabled && !root.busy && root._eqNodeId >= 0
    repeat: true
    onTriggered: _relinkProc.running = true
  }

  Process {
    id: _relinkProc
    // sinkName — константа "SELFshell_EQ", екрануємо на випадок зміни
    readonly property string _relinkEqQ: "'" + root.sinkName.replace(/'/g, "'\\''") + "'"
    command: ["bash", "-c",
      "SRC=$(pw-link -o 2>/dev/null | grep 'output.filter-chain' | head -1 | cut -d: -f1); " +
      "[ -z \"$SRC\" ] && exit 0; " +
      "LINKS=$(pw-link -l 2>/dev/null); " +
      "if pactl list short sinks 2>/dev/null | grep -q \"bluez\"; then " +
      "  BEST=$(pactl list short sinks 2>/dev/null | grep \"bluez\" | head -1 | cut -f2); " +
      "  [ -z \"$BEST\" ] && exit 0; " +
      "  for T in $(pactl list short sinks 2>/dev/null | grep -v " + _relinkEqQ + " | cut -f2); do " +
      "    if [ \"$T\" != \"$BEST\" ]; then " +
      "      if echo \"$LINKS\" | grep -q \"$T:playback_FL\"; then " +
      "        pw-link -d \"$SRC:output_FL\" \"$T:playback_FL\" 2>/dev/null || true; " +
      "        pw-link -d \"$SRC:output_FR\" \"$T:playback_FR\" 2>/dev/null || true; " +
      "      fi; " +
      "    fi; " +
      "  done; " +
      "  if ! echo \"$LINKS\" | grep -q \"$BEST:playback_FL\"; then " +
      "    pw-link \"$SRC:output_FL\" \"$BEST:playback_FL\" 2>/dev/null || true; " +
      "    pw-link \"$SRC:output_FR\" \"$BEST:playback_FR\" 2>/dev/null || true; " +
      "  fi; " +
      "else " +
      "  for T in $(pactl list short sinks 2>/dev/null | grep -v " + _relinkEqQ + " | cut -f2); do " +
      "    if ! echo \"$LINKS\" | grep -q \"$T:playback_FL\"; then " +
      "      pw-link \"$SRC:output_FL\" \"$T:playback_FL\" 2>/dev/null || true; " +
      "      pw-link \"$SRC:output_FR\" \"$T:playback_FR\" 2>/dev/null || true; " +
      "    fi; " +
      "  done; " +
      "fi"
    ]
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
    // watchChanges лишаємо false — той самий UAF що в AppConfig (див. AudioEq:14)
    // Зовнішні правки eq.json застосовуються після рестарту; мертвий onFileChanged прибрано
    watchChanges: false
    onDataChanged: root._stateReady()
    onLoadFailed: root._stateReady()
  }

  FileView {
    id: _confFile
    path: "file://" + root.confPath
    watchChanges: false
    onSaved: {
      if (root._confRestartPending) {
        root._confRestartPending = false
        _pwRestartProc.running = true
      }
    }
  }
}
