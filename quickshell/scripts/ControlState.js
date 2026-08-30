// ============================================================
// quickshell/scripts/ControlState.js — збереження стану контрол центру
// ============================================================
.pragma library

var _data = {}

function setData(data) {
  _data = data || {}
}

function setBrightness(v) { _data.brightness = v }
function setReadingTemp(v) { _data.readingTemp = v }
function setMuted(v) { _data.muted = v }
function setCaffeine(v) { _data.caffeine = v }

function getBrightness() {
  return _data.brightness != null ? _data.brightness : -1
}

function getReadingTemp() {
  return _data.readingTemp != null ? _data.readingTemp : 6500
}

function getMuted() {
  return _data.muted != null ? _data.muted : false
}

function getCaffeine() {
  return _data.caffeine != null ? _data.caffeine : false
}

function serialize() {
  return JSON.stringify({ brightness: _data.brightness, readingTemp: _data.readingTemp, muted: _data.muted, caffeine: _data.caffeine })
}
