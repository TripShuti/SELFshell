// ============================================================
// PaletteService.qml — реактивна палітра кольорів з FileView.
// Стежить за data/palette.json, оновлює кольори на льоту
// ============================================================
import Quickshell.Io
import QtQuick

Item {
  id: root
  visible: false

  FileView {
    id: paletteFile
    // blockLoading — перший text() (в onCompleted) робить синхронне
    // читання, палітра готова до першого кадру; інакше бар на мить
    // показує захардкоджені дефолти (async read ще в дорозі)
    preload: false
    blockLoading: true
    path: Qt.resolvedUrl("../data/palette.json")

    onDataChanged: root._parse(paletteFile.text())
  }

  Component.onCompleted: {
    root._parse(paletteFile.text())
  }

  function reload() {
    var p = paletteFile.path
    paletteFile.path = ""
    paletteFile.path = p
  }

  property string font: "JetBrainsMonoNL Nerd Font"

  property string fg: "#ede0d4"
  property string gray: "#9b8f80"
  property string green: "#e79c06"
  property string red: "#ffb4ab"

  property string bg0H: "#34302a"
  property string bg1: "#403b35"
  property string bg2: "#57514b"
  property string muted: "#d3c4b4"
  property string light: "#eae1d9"
  property string bright: "#f9efe7"

  property string yellow: "#b8cea1"
  property string blue: "#ddc2a1"
  property string purple: "#c0a788"
  property string orange: "#e79c06"
  property string aqua: "#9db288"

  property string widgetFg: "#f0d2ab"
  property string audioVolume: "#b8cea1"

  property string hoverOverlay: "#14ffffff"
  property string pressOverlay: "#1fffffff"

  property string bgAlpha: "#9934302a"
  property string hoverBg: "#99433e37"
  property string baseOverlay: "#9934302a"
  property string softOverlay: "#a634302a"

  property string accent: "#f4bd6e"
  property string textLight: "#f9efe7"
  property string mutedAlt: "#b4a799"
  property string danger: "#ffb4ab"
  property string bgLayer: "#99383129"
  property string sepBg: "#99f4bd6e"
  property string outlineVariant: "#6657514b"

  function _parse(text) {
    if (!text) return
    try {
      var data = JSON.parse(text)
      if (data.font !== undefined) font = data.font
      if (data.fg !== undefined) fg = data.fg
      if (data.gray !== undefined) gray = data.gray
      if (data.green !== undefined) green = data.green
      if (data.red !== undefined) red = data.red
      if (data.bg0H !== undefined) bg0H = data.bg0H
      if (data.bg1 !== undefined) bg1 = data.bg1
      if (data.bg2 !== undefined) bg2 = data.bg2
      if (data.muted !== undefined) muted = data.muted
      if (data.light !== undefined) light = data.light
      if (data.bright !== undefined) bright = data.bright
      if (data.yellow !== undefined) yellow = data.yellow
      if (data.blue !== undefined) blue = data.blue
      if (data.purple !== undefined) purple = data.purple
      if (data.orange !== undefined) orange = data.orange
      if (data.aqua !== undefined) aqua = data.aqua
      if (data.widgetFg !== undefined) widgetFg = data.widgetFg
      if (data.audioVolume !== undefined) audioVolume = data.audioVolume
      if (data.hoverOverlay !== undefined) hoverOverlay = data.hoverOverlay
      if (data.pressOverlay !== undefined) pressOverlay = data.pressOverlay
      if (data.bgAlpha !== undefined) bgAlpha = data.bgAlpha
      if (data.hoverBg !== undefined) hoverBg = data.hoverBg
      if (data.baseOverlay !== undefined) baseOverlay = data.baseOverlay
      if (data.softOverlay !== undefined) softOverlay = data.softOverlay
      if (data.accent !== undefined) accent = data.accent
      if (data.textLight !== undefined) textLight = data.textLight
      if (data.mutedAlt !== undefined) mutedAlt = data.mutedAlt
      if (data.danger !== undefined) danger = data.danger
      if (data.bgLayer !== undefined) bgLayer = data.bgLayer
      if (data.sepBg !== undefined) sepBg = data.sepBg
      if (data.outlineVariant !== undefined) outlineVariant = data.outlineVariant
    } catch (e) {
      console.warn("PaletteService: не вдалось розпарсити palette.json", e)
    }
  }
}
