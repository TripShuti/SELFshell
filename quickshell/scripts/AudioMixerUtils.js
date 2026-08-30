// ============================================================
// quickshell/scripts/AudioMixerUtils.js — чисті хелпери для AudioMixerPopup: форматування гучності та мапінг потоків → пристроїв
// ============================================================
.pragma library

function clamp01(v) {
  return Math.max(0, Math.min(1, v))
}

function formatPercent(v) {
  return Math.round(clamp01(v) * 100) + "%"
}

function formatDb(v) {
  if (v <= 0.0001) return "-inf dB"
  var db = 20 * (Math.log10 ? Math.log10(v) : Math.log(v) / Math.LN10)
  return db.toFixed(2) + " dB"
}

// Мапінг sink-input → sink name через pactl sinkInputsInfo + sinkPortMap
// + fallback у Pipewire.nodes. Зберігає існуючу семантику AudioMixerPopup,
// але як чиста функція (без доступу до root) — легше тестувати.
// FIXME: pactl index vs PipeWire object.serial — різні домени ID,
// збіг можливий випадково; потребує перевірки на pipewire-pulse 1.2
function sinkNameForStream(streamNode, sinkInputsInfo, sinkPortMap, pipewireValues) {
  if (!streamNode || !streamNode.properties) return ""
  var serial = streamNode.properties["object.serial"]
  if (serial === undefined || serial === null) return ""
  var sserial = String(serial)
  for (var i = 0; i < (sinkInputsInfo ? sinkInputsInfo.length : 0); i++) {
    var si = sinkInputsInfo[i]
    var siSerial = String(si.properties ? si.properties["object.serial"] : si.index)
    if (siSerial === sserial || String(si.index) === sserial) {
      var sinkIdx = si.sink
      for (var name in sinkPortMap) {
        if (sinkPortMap[name].index === sinkIdx) return name
      }
      if (pipewireValues) {
        for (var j = 0; j < pipewireValues.length; j++) {
          var n = pipewireValues[j]
          if (n.properties["object.serial"] && String(n.properties["object.serial"]) === String(sinkIdx)) return n.name
          if (n.type === PwNodeType.AudioSink && n.properties["object.id"] && String(n.properties["object.id"]) === String(sinkIdx)) return n.name
        }
      }
      return ""
    }
  }
  return ""
}

function sourceNameForStream(streamNode, sourceOutputsInfo, sourcePortMap, pipewireValues) {
  if (!streamNode || !streamNode.properties) return ""
  var serial = streamNode.properties["object.serial"]
  if (serial === undefined || serial === null) return ""
  var sserial = String(serial)
  for (var i = 0; i < (sourceOutputsInfo ? sourceOutputsInfo.length : 0); i++) {
    var si = sourceOutputsInfo[i]
    var siSerial = String(si.properties ? si.properties["object.serial"] : si.index)
    if (siSerial === sserial || String(si.index) === sserial) {
      var srcIdx = si.source
      for (var name in sourcePortMap) {
        if (sourcePortMap[name].index === srcIdx) return name
      }
      if (pipewireValues) {
        for (var j = 0; j < pipewireValues.length; j++) {
          var n = pipewireValues[j]
          if (n.properties["object.serial"] && String(n.properties["object.serial"]) === String(srcIdx)) return n.name
        }
      }
      return ""
    }
  }
  return ""
}

function sinkDescription(name, sinkPortMap, pipewireValues) {
  if (pipewireValues) {
    for (var i = 0; i < pipewireValues.length; i++) {
      if (pipewireValues[i].name === name) return pipewireValues[i].description || pipewireValues[i].nickname || pipewireValues[i].name
    }
  }
  if (sinkPortMap[name] && sinkPortMap[name].description) return sinkPortMap[name].description
  return name
}

function sourceDescription(name, sourcePortMap, pipewireValues) {
  if (pipewireValues) {
    for (var i = 0; i < pipewireValues.length; i++) {
      if (pipewireValues[i].name === name) return pipewireValues[i].description || pipewireValues[i].nickname || pipewireValues[i].name
    }
  }
  if (sourcePortMap[name] && sourcePortMap[name].description) return sourcePortMap[name].description
  return name
}
