// ============================================================
// quickshell/popups/AudioMixerPopup.qml — мікшер аудіо в стилі pavucontrol (5 вкладок: потоки, пристрої, профілі)
// ============================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"
import "../scripts/AudioMixerUtils.js" as AudioUtils
import "audio"
import QtQuick
import QtQuick.Layouts

AnimatedPopup {
  id: root

  required property QtObject anchorItem
  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  // Центрований як SettingsPopup, а не під якорем (pavucontrol — окреме вікно)
  implicitWidth: 480
  implicitHeight: 480
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  readonly property int screenW: window ? window.screen.width : 1920
  readonly property int screenH: window ? window.screen.height : 1080

  function recenter() {
    anchor.rect = Qt.rect(
      (screenW - root.implicitWidth) / 2,
      (screenH - root.implicitHeight) / 2,
      root.implicitWidth,
      root.implicitHeight
    )
  }

  Component.onCompleted: {
    anchor.window = window
    root.refreshAll()
  }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      root.recenter()
      root.refreshAll()
      pollTimer.running = true
      Qt.callLater(() => layout.forceLayout())
    } else {
      pollTimer.running = false
    }
  }

  // --- Стан вкладок ---
  property int selectedTab: 2 // 0 Playback, 1 Recording, 2 Output, 3 Input, 4 Config
  readonly property var tabNames: ["Playback", "Recording", "Output Devices", "Input Devices", "Configuration"]
  property bool showVirtual: false

  // --- Дані з pactl ---
  property var cardsModel: []
  property var sinkPortMap: ({})
  property var sourcePortMap: ({})
  property var sinkInputsInfo: []
  property var sourceOutputsInfo: []

  // Фільтровані ноди — один прохід по Pipewire.nodes.values (4 масиви за 1 цикл)
  readonly property var _filtered: {
    if (!Pipewire.ready || !Pipewire.nodes || !Pipewire.nodes.values) return {playback:[], recording:[], output:[], input:[]}
    var vals = Pipewire.nodes.values
    var p=[], r=[], o=[], i=[]
    for (var idx = 0; idx < vals.length; idx++) {
      var n = vals[idx]
      if (!n || !n.audio) continue
      if (n.isStream) {
        if (n.isSink) {
          if (!root.showVirtual && n.properties["node.virtual"] === "true") continue
          p.push(n)
        } else {
          if (!root.showVirtual && n.properties["node.virtual"] === "true") continue
          r.push(n)
        }
      } else if (n.isSink) {
        o.push(n)
      } else {
        if (n.properties["media.class"] && n.properties["media.class"] !== "Audio/Source") continue
        i.push(n)
      }
    }
    return {playback:p, recording:r, output:o, input:i}
  }
  readonly property var playbackNodes: _filtered.playback
  readonly property var recordingNodes: _filtered.recording
  readonly property var outputNodes: _filtered.output
  readonly property var inputNodes: _filtered.input

  // ScriptModel обгортки для Repeater (як у BluetoothPopup.qml:200) — стабільні моделі, тільки видимі делегати
  ScriptModel { id: playbackSM; values: root.playbackNodes }
  ScriptModel { id: recordingSM; values: root.recordingNodes }
  ScriptModel { id: outputSM; values: root.outputNodes }
  ScriptModel { id: inputSM; values: root.inputNodes }

  // для EmptyState
  readonly property int playbackVisibleCount: playbackNodes.length
  readonly property int recordingVisibleCount: recordingNodes.length
  readonly property int outputVisibleCount: outputNodes.length
  readonly property int inputVisibleCount: inputNodes.length

  // Кеш sink/source імен для O(1) lookup в StreamCard (замість O(N*M) в біндингах)
  readonly property var sinkNameMap: {
    var map = {}
    var pVals = Pipewire.nodes ? Pipewire.nodes.values : null
    for (var s = 0; s < root.sinkInputsInfo.length; s++) {
      var si = root.sinkInputsInfo[s]
      if (!si) continue
      var siSerial = String(si.properties ? si.properties["object.serial"] : si.index)
      var sinkIdx = si.sink
      var name = ""
      for (var n in root.sinkPortMap) if (root.sinkPortMap[n].index === sinkIdx) { name = n; break }
      if (!name && pVals) {
        for (var j = 0; j < pVals.length; j++) {
          var pn = pVals[j]
          if (!pn || !pn.properties) continue
          if (pn.properties["object.serial"] && String(pn.properties["object.serial"]) === String(sinkIdx)) { name = pn.name; break }
          if (pn.type === PwNodeType.AudioSink && pn.properties["object.id"] && String(pn.properties["object.id"]) === String(sinkIdx)) { name = pn.name; break }
        }
      }
      if (name) {
        map[siSerial] = name
        map[String(si.index)] = name
      }
    }
    return map
  }
  readonly property var sourceNameMap: {
    var map = {}
    var pVals2 = Pipewire.nodes ? Pipewire.nodes.values : null
    for (var s2 = 0; s2 < root.sourceOutputsInfo.length; s2++) {
      var so = root.sourceOutputsInfo[s2]
      if (!so) continue
      var soSerial = String(so.properties ? so.properties["object.serial"] : so.index)
      var srcIdx = so.source
      var sname = ""
      for (var nn in root.sourcePortMap) if (root.sourcePortMap[nn].index === srcIdx) { sname = nn; break }
      if (!sname && pVals2) {
        for (var k = 0; k < pVals2.length; k++) {
          var pk = pVals2[k]
          if (!pk || !pk.properties) continue
          if (pk.properties["object.serial"] && String(pk.properties["object.serial"]) === String(srcIdx)) { sname = pk.name; break }
        }
      }
      if (sname) {
        map[soSerial] = sname
        map[String(so.index)] = sname
      }
    }
    return map
  }

  // Кеш описів пристроїв для O(1) lookup
  readonly property var sinkDescMap: {
    var m = {}
    var vals2 = Pipewire.nodes ? Pipewire.nodes.values : null
    if (vals2) for (var i2 = 0; i2 < vals2.length; i2++) { var nn = vals2[i2]; if (nn && nn.name) m[nn.name] = nn.description || nn.nickname || nn.name }
    for (var kk in root.sinkPortMap) if (!m[kk] && root.sinkPortMap[kk].description) m[kk] = root.sinkPortMap[kk].description
    return m
  }
  readonly property var sourceDescMap: {
    var m2 = {}
    var vals3 = Pipewire.nodes ? Pipewire.nodes.values : null
    if (vals3) for (var j2 = 0; j2 < vals3.length; j2++) { var mm = vals3[j2]; if (mm && mm.name) m2[mm.name] = mm.description || mm.nickname || mm.name }
    for (var kk2 in root.sourcePortMap) if (!m2[kk2] && root.sourcePortMap[kk2].description) m2[kk2] = root.sourcePortMap[kk2].description
    return m2
  }

  // --- Допоміжні функції — делегують у AudioMixerUtils.js ---
  function formatPercent(v) { return AudioUtils.formatPercent(v) }
  function formatDb(v) { return AudioUtils.formatDb(v) }
  function sinkNameForStream(streamNode) {
    var serial = streamNode && streamNode.properties ? String(streamNode.properties["object.serial"] || "") : ""
    if (serial && root.sinkNameMap[serial]) return root.sinkNameMap[serial]
    return AudioUtils.sinkNameForStream(streamNode, root.sinkInputsInfo, root.sinkPortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
  }
  function sourceNameForStream(streamNode) {
    var serial2 = streamNode && streamNode.properties ? String(streamNode.properties["object.serial"] || "") : ""
    if (serial2 && root.sourceNameMap[serial2]) return root.sourceNameMap[serial2]
    return AudioUtils.sourceNameForStream(streamNode, root.sourceOutputsInfo, root.sourcePortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
  }
  function sinkDescription(name) {
    if (root.sinkDescMap[name]) return root.sinkDescMap[name]
    return AudioUtils.sinkDescription(name, root.sinkPortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
  }
  function sourceDescription(name) {
    if (root.sourceDescMap[name]) return root.sourceDescMap[name]
    return AudioUtils.sourceDescription(name, root.sourcePortMap, Pipewire.nodes ? Pipewire.nodes.values : null)
  }

  function refreshAll() {
    root.refreshCards()
    root.refreshSinks()
    root.refreshSources()
    root.refreshSinkInputs()
    root.refreshSourceOutputs()
  }
  function refreshCards() {
    _cardsProc.command = ["pactl", "-f", "json", "list", "cards"]
    _cardsProc.running = true
  }
  function refreshSinks() {
    _sinksProc.command = ["pactl", "-f", "json", "list", "sinks"]
    _sinksProc.running = true
  }
  function refreshSources() {
    _sourcesProc.command = ["pactl", "-f", "json", "list", "sources"]
    _sourcesProc.running = true
  }
  function refreshSinkInputs() {
    _sinkInputsProc.command = ["pactl", "-f", "json", "list", "sink-inputs"]
    _sinkInputsProc.running = true
  }
  function refreshSourceOutputs() {
    _sourceOutputsProc.command = ["pactl", "-f", "json", "list", "source-outputs"]
    _sourceOutputsProc.running = true
  }

  // --- Процеси для дій — логуємо помилки pactl/pw-cli ---
  Process { id: _moveStreamsProc; onExited: (code) => { if (code !== 0) console.warn("[AudioMixer] move-stream failed", code, command); running = false } }
  Process { id: _destroyProc; onExited: (code) => { if (code !== 0) console.warn("[AudioMixer] destroy failed", code); running = false } }
  Process { id: _portProc; onExited: (code) => { if (code !== 0) console.warn("[AudioMixer] set-port failed", code); running = false } }
  Process { id: _profileProc; onExited: (code) => { if (code !== 0) console.warn("[AudioMixer] set-profile failed", code); running = false } }
  Process { id: _defaultSinkProc; onExited: (code) => { if (code !== 0) console.warn("[AudioMixer] set-default-sink failed", code); running = false } }
  Process { id: _defaultSourceProc; onExited: (code) => { if (code !== 0) console.warn("[AudioMixer] set-default-source failed", code); running = false } }

  // --- Завантаження списків ---
  Process {
    id: _cardsProc
    stdout: StdioCollector {
      id: _cardsCollector
      waitForEnd: true
      onStreamFinished: {
        var text = _cardsCollector.text.trim()
        if (!text) { root.cardsModel = []; return }
        try {
          var arr = JSON.parse(text)
          root.cardsModel = arr
        } catch (e) {
          console.warn("[AudioMixer] cards parse fail", e)
          root.cardsModel = []
        }
      }
    }
  }
  Process {
    id: _sinksProc
    stdout: StdioCollector {
      id: _sinksCollector
      waitForEnd: true
      onStreamFinished: {
        var text = _sinksCollector.text.trim()
        if (!text) return
        try {
          var arr = JSON.parse(text)
          var map = {}
          for (var i = 0; i < arr.length; i++) {
            var s = arr[i]
            map[s.name] = s
          }
          root.sinkPortMap = map
        } catch (e) { console.warn("[AudioMixer] sinks parse fail", e) }
      }
    }
  }
  Process {
    id: _sourcesProc
    stdout: StdioCollector {
      id: _sourcesCollector
      waitForEnd: true
      onStreamFinished: {
        var text = _sourcesCollector.text.trim()
        if (!text) return
        try {
          var arr = JSON.parse(text)
          var map = {}
          for (var i = 0; i < arr.length; i++) {
            var s = arr[i]
            map[s.name] = s
          }
          root.sourcePortMap = map
        } catch (e) { console.warn("[AudioMixer] sources parse fail", e) }
      }
    }
  }
  Process {
    id: _sinkInputsProc
    stdout: StdioCollector {
      id: _sinkInputsCollector
      waitForEnd: true
      onStreamFinished: {
        var text = _sinkInputsCollector.text.trim()
        if (!text) { root.sinkInputsInfo = []; return }
        try {
          var arr = JSON.parse(text)
          root.sinkInputsInfo = arr
        } catch (e) { console.warn("[AudioMixer] sink-inputs parse fail", e); root.sinkInputsInfo = [] }
      }
    }
  }
  Process {
    id: _sourceOutputsProc
    stdout: StdioCollector {
      id: _sourceOutputsCollector
      waitForEnd: true
      onStreamFinished: {
        var text = _sourceOutputsCollector.text.trim()
        if (!text) { root.sourceOutputsInfo = []; return }
        try {
          var arr = JSON.parse(text)
          root.sourceOutputsInfo = arr
        } catch (e) { console.warn("[AudioMixer] source-outputs parse fail", e); root.sourceOutputsInfo = [] }
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 2500
    repeat: true
    running: false
    onTriggered: {
      if (root.selectedTab === 0 || root.selectedTab === 1) {
        root.refreshSinkInputs(); root.refreshSourceOutputs()
      } else if (root.selectedTab === 2) {
        root.refreshSinks()
      } else if (root.selectedTab === 3) {
        root.refreshSources()
      } else if (root.selectedTab === 4) {
        root.refreshCards()
      }
    }
  }

  ColumnLayout {
    id: layout
    x: 8
    y: 8
    width: parent.width - 16
    spacing: 8

    MixerTabBar {
      window: root.window
      tabNames: root.tabNames
      selectedTab: root.selectedTab
      onTabPicked: index => root.selectedTab = index
    }



    // --- Контейнер вкладок ---
    Item {
      id: tabsContainer
      Layout.fillWidth: true
      readonly property real _playbackH: playbackFlick.contentHeight
      readonly property real _recordingH: recordingFlick.contentHeight
      readonly property real _outputH: outputFlick.contentHeight
      readonly property real _inputH: inputFlick.contentHeight
      readonly property real _configH: configFlick.contentHeight
      readonly property real _activeH: {
        if (root.selectedTab === 0) return _playbackH
        if (root.selectedTab === 1) return _recordingH
        if (root.selectedTab === 2) return _outputH
        if (root.selectedTab === 3) return _inputH
        return _configH
      }
      implicitHeight: Math.max(120, Math.min(_activeH, 420))
      Behavior on implicitHeight { NumberAnimation { duration: appConfig.anim(200); easing.type: Easing.OutCubic } }
      clip: true

      // ===== Відтворення =====
      Flickable {
        id: playbackFlick
        width: parent.width
        height: parent.height
        visible: root.selectedTab === 0
        contentWidth: width
          contentHeight: playbackCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          clip: true

          ColumnLayout {
            id: playbackCol
            width: parent.width
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "Playback"
                color: window.palette.green
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
                Layout.fillWidth: true
              }
              Text {
                text: "Show virtual"
                color: window.palette.gray
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
              }
              ToggleSwitch {
                checked: root.showVirtual
                palette: window.palette
                appConfig: window.appConfig
                checkedColor: window.palette.green
                trackWidth: 28; trackHeight: 16; knobSize: 12
                onToggled: v => root.showVirtual = v
              }
            }

            EmptyState {
              window: root.window
              visible: root.playbackVisibleCount === 0
              text: "No application is currently playing audio."
              boxHeight: 60
            }

            Repeater {
              model: playbackSM
              delegate: StreamCard {
                required property var modelData
                window: root.window
                streamNode: modelData
                isPlayback: true
                sinkInputsInfo: root.sinkInputsInfo
                sinkPortMap: root.sinkPortMap
                sourceOutputsInfo: root.sourceOutputsInfo
                sourcePortMap: root.sourcePortMap
                sinkNameMap: root.sinkNameMap
                sourceNameMap: root.sourceNameMap
                sinkDescMap: root.sinkDescMap
                sourceDescMap: root.sourceDescMap
                sinkDevices: root.outputNodes
                sourceDevices: root.inputNodes
                onMoveStream: (serial, targetName) => {
                  _moveStreamsProc.command = ["pactl", "move-sink-input", serial, targetName]
                  _moveStreamsProc.running = true
                }
                onDestroyStream: objectId => {
                  _destroyProc.command = ["pw-cli", "destroy", objectId]
                  _destroyProc.running = true
                }
              }
            }
          }
        }

        // ===== Запис =====
        Flickable {
          id: recordingFlick
          width: parent.width
          height: parent.height
          visible: root.selectedTab === 1
          contentWidth: width
          contentHeight: recordingCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          clip: true

          ColumnLayout {
            id: recordingCol
            width: parent.width
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "Recording"
                color: window.palette.green
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
                Layout.fillWidth: true
              }
              Text {
                text: "Show virtual"
                color: window.palette.gray
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
              }
              ToggleSwitch {
                checked: root.showVirtual
                palette: window.palette
                appConfig: window.appConfig
                checkedColor: window.palette.green
                trackWidth: 28; trackHeight: 16; knobSize: 12
                onToggled: v => root.showVirtual = v
              }
            }

            EmptyState {
              window: root.window
              visible: root.recordingVisibleCount === 0
              text: "No application is currently recording audio."
              boxHeight: 60
            }

            Repeater {
              model: recordingSM
              delegate: StreamCard {
                required property var modelData
                window: root.window
                streamNode: modelData
                isPlayback: false
                sinkInputsInfo: root.sinkInputsInfo
                sinkPortMap: root.sinkPortMap
                sourceOutputsInfo: root.sourceOutputsInfo
                sourcePortMap: root.sourcePortMap
                sinkNameMap: root.sinkNameMap
                sourceNameMap: root.sourceNameMap
                sinkDescMap: root.sinkDescMap
                sourceDescMap: root.sourceDescMap
                sinkDevices: root.outputNodes
                sourceDevices: root.inputNodes
                onMoveStream: (serial, targetName) => {
                  _moveStreamsProc.command = ["pactl", "move-source-output", serial, targetName]
                  _moveStreamsProc.running = true
                }
                onDestroyStream: objectId => {
                  _destroyProc.command = ["pw-cli", "destroy", objectId]
                  _destroyProc.running = true
                }
              }
            }
          }
        }

        // ===== Пристрої виведення =====
        Flickable {
          id: outputFlick
          width: parent.width
          height: parent.height
          visible: root.selectedTab === 2
          contentWidth: width
          contentHeight: outputCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          clip: true

          ColumnLayout {
            id: outputCol
            width: parent.width
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "Output Devices"
                color: window.palette.green
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
                Layout.fillWidth: true
              }
            }

            EmptyState {
              window: root.window
              visible: root.outputVisibleCount === 0
              text: "No output devices available."
              boxHeight: 40
            }

            Repeater {
              model: outputSM
              delegate: DeviceCard {
                required property var modelData
                window: root.window
                deviceNode: modelData
                isSink: true
                portMap: root.sinkPortMap
                isDefault: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name === modelData.name : false
                onSetDefaultRequested: {
                  if (!modelData.audio) return
                  if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.name === modelData.name) return
                  Pipewire.preferredDefaultAudioSink = modelData
                  var t = modelData.name.replace(/'/g, "'\\''")
                  _moveStreamsProc.command = ["bash", "-c", "T='" + t + "'; pactl list short sink-inputs 2>/dev/null | cut -f1 | xargs -r -n1 -I{} pactl move-sink-input {} \"$T\""]
                  _moveStreamsProc.running = true
                }
                onSetPortRequested: portName => {
                  _portProc.command = ["pactl", "set-sink-port", modelData.name, portName]
                  _portProc.running = true
                }
              }
            }
          }
        }

        // ===== Пристрої введення =====
        Flickable {
          id: inputFlick
          width: parent.width
          height: parent.height
          visible: root.selectedTab === 3
          contentWidth: width
          contentHeight: inputCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          clip: true

          ColumnLayout {
            id: inputCol
            width: parent.width
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: "Input Devices"
                color: window.palette.green
                font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
                Layout.fillWidth: true
              }
            }

            EmptyState {
              window: root.window
              visible: root.inputVisibleCount === 0
              text: "No input devices available."
              boxHeight: 40
            }

            Repeater {
              model: inputSM
              delegate: DeviceCard {
                required property var modelData
                window: root.window
                deviceNode: modelData
                isSink: false
                portMap: root.sourcePortMap
                isDefault: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.name === modelData.name : false
                onSetDefaultRequested: {
                  if (!modelData.audio) return
                  if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.name === modelData.name) return
                  Pipewire.preferredDefaultAudioSource = modelData
                  var t = modelData.name.replace(/'/g, "'\\''")
                  _moveStreamsProc.command = ["bash", "-c", "T='" + t + "'; pactl list short source-outputs 2>/dev/null | cut -f1 | xargs -r -n1 -I{} pactl move-source-output {} \"$T\""]
                  _moveStreamsProc.running = true
                }
                onSetPortRequested: portName => {
                  _portProc.command = ["pactl", "set-source-port", modelData.name, portName]
                  _portProc.running = true
                }
              }
            }
          }
        }

        // ===== Конфігурація =====
        Flickable {
          id: configFlick
          width: parent.width
          height: parent.height
          visible: root.selectedTab === 4
          contentWidth: width
          contentHeight: configCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          clip: true

          ColumnLayout {
            id: configCol
            width: parent.width
            spacing: 8

            Text {
              text: "Configuration"
              color: window.palette.green
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(12); font.bold: true
            }
            Text {
              text: "Select a profile for each card. 'Off' disables the card."
              color: window.palette.gray
              font.family: window.palette.font; font.pixelSize: appConfig.scaled(9)
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            EmptyState {
              window: root.window
              visible: root.cardsModel.length === 0
              text: "No cards available."
              boxHeight: 40
            }

            Repeater {
              model: root.cardsModel
              delegate: ConfigCard {
                required property var modelData
                window: root.window
                cardData: modelData
                onProfilePicked: (cardName, profileId) => {
                  _profileProc.command = ["pactl", "set-card-profile", cardName, profileId]
                  _profileProc.running = true
                }
              }
            }
          }
        }
    }
  }
}
