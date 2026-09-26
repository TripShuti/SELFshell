// ============================================================
// quickshell/scripts/Format.js — спільне форматування значень для QML
// ============================================================
.pragma library

// Секунди в "m:ss" (медіа-позиції, тривалості). Спільна для
// PlaybackControls/PlaylistSection (було три копії + одна мертва).
function formatTime(secs) {
  if (isNaN(secs) || secs < 0) return "0:00"
  var m = Math.floor(secs / 60)
  var s = Math.floor(secs % 60)
  return m + ":" + (s < 10 ? "0" : "") + s
}
