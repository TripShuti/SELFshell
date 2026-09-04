// ============================================================
// quickshell/scripts/SelfTrack.js — форматування та кольори для трекера часу
// ============================================================

// Поточна локальна дата YYYY-MM-DD (не UTC: UTC дає вчорашній день
// у перші години доби для східних поясів)
function todayStr() {
  var d = new Date()
  return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
}

// Повний формат тривалості з мілісекунд (04:12:30)
function formatDur(ms) {
  var total = Math.max(0, Math.floor(ms / 1000))
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  var s = total % 60
  return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
}

// Короткий формат для віджета бару (4h12m або 36m)
function formatShort(ms) {
  var total = Math.max(0, Math.floor(ms / 1000))
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  if (h > 0) return h + "h" + String(m).padStart(2, "0") + "m"
  return m + "m"
}

// Час доби з epoch-мілісекунд (10:24)
function formatClock(ms) {
  var d = new Date(ms)
  return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
}

// Час доби з секундами (10:24:31) — для глибокого зуму таймлайну
function formatClockS(ms) {
  var d = new Date(ms)
  return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0") + ":" + String(d.getSeconds()).padStart(2, "0")
}

// Початок локальної доби для дати YYYY-MM-DD (epoch ms)
function dayStartMs(dateStr) {
  var p = String(dateStr).split("-")
  return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2])).getTime()
}

// Стабільний індекс кольору застосунку (за хешем назви)
function appColorIndex(app, count) {
  var s = String(app)
  var h = 0
  for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 100000
  return h % count
}

// Чистить суфікс браузера з тайтла вкладки (як clean_page_title в selftrack)
function cleanTitle(title) {
  var t = String(title).trim()
  var suffixes = [" — Mozilla Firefox", " - Mozilla Firefox", " — Chromium",
    " - Chromium", " — Google Chrome", " - Google Chrome", " — Brave",
    " - Brave", " — Vivaldi", " - Vivaldi", " — Opera", " - Opera"]
  for (var i = 0; i < suffixes.length; i++) {
    if (t.endsWith(suffixes[i])) return t.substring(0, t.length - suffixes[i].length).trim()
  }
  return t
}
