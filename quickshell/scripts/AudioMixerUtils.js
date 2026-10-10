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

// Порівнюємо ID лише в одному просторі: serial із serial, object.id із object.id.
// Pulse index застосовується до pactl тільки після знаходження відповідного запису.
function idKey(value) {
  return value !== undefined && value !== null && /^\d+$/.test(String(value)) ? String(value) : ""
}

function streamInfo(streamNode, entries) {
  if (!streamNode || !streamNode.properties) return null
  var props = streamNode.properties
  for (var i = 0; i < (entries ? entries.length : 0); i++) {
    var entry = entries[i]
    if (!entry || !entry.properties) continue
    var other = entry.properties
    var serial = idKey(props["object.serial"])
    var otherSerial = idKey(other["object.serial"])
    if (serial && otherSerial) {
      if (serial === otherSerial) return entry
      continue
    }
    var objectId = idKey(props["object.id"])
    if (objectId && objectId === idKey(other["object.id"])) return entry
  }
  return null
}

function streamIndex(streamNode, entries) {
  var entry = streamInfo(streamNode, entries)
  return entry ? idKey(entry.index) : ""
}

function streamNameMap(entries, portMap, targetKey) {
  var devices = {}
  var result = {}
  for (var name in portMap) {
    var device = portMap[name]
    if (device && idKey(device.index)) devices[idKey(device.index)] = name
  }
  for (var i = 0; i < (entries ? entries.length : 0); i++) {
    var entry = entries[i]
    if (!entry || !entry.properties) continue
    var serial = idKey(entry.properties["object.serial"])
    var target = devices[idKey(entry[targetKey])]
    if (serial && target) result[serial] = target
  }
  return result
}

function streamDeviceName(streamNode, entries, portMap, targetKey) {
  var entry = streamInfo(streamNode, entries)
  if (!entry) return ""
  for (var name in portMap) {
    if (portMap[name] && idKey(portMap[name].index) && idKey(portMap[name].index) === idKey(entry[targetKey])) return name
  }
  return ""
}

function sinkNameForStream(streamNode, sinkInputsInfo, sinkPortMap) {
  return streamDeviceName(streamNode, sinkInputsInfo, sinkPortMap, "sink")
}

function sourceNameForStream(streamNode, sourceOutputsInfo, sourcePortMap) {
  return streamDeviceName(streamNode, sourceOutputsInfo, sourcePortMap, "source")
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
