// ============================================================
// EqPresets.js — пресети еквалайзера (класичні значення Winamp)
// ============================================================
.pragma library

// Смуги mbeq_1197 (LADSPA), Гц — порялок портів 0..14
var mbeqBands = [
  50, 100, 156, 220, 311, 440, 622, 880,
  1250, 1750, 2500, 3500, 5000, 10000, 20000
]

// Класичні 10 смуг Winamp, Гц
var winampBands = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]

// Пресети у значеннях Winamp (10 смуг, dB)
var winampPresets = {
  "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  "Classical": [0, 0, 0, 0, 0, 0, -7, -7, -7, -6],
  "Club": [0, 0, 8, 6, 5, 5, 3, 0, 0, 0],
  "Dance": [9, 7, 2, 0, 0, -5, -7, -7, 0, 0],
  "Full Bass": [-8, 9, 9, 5, 1, -4, -8, -10, -11, -11],
  "Full Bass & Treble": [7, 5, 0, -7, -4, 1, 8, 11, 12, 12],
  "Full Treble": [-9, -9, -9, -4, 2, 11, 16, 16, 16, 16],
  "Laptop / Headphones": [4, 11, 5, -3, -2, 1, 4, 9, 12, 14],
  "Large Hall": [10, 10, 5, 5, 0, -4, -4, -4, 0, 0],
  "Party": [7, 7, 0, 0, 0, 0, 0, 0, 7, 7],
  "Pop": [-1, 1, 7, 8, 5, 0, -2, -2, -1, -1],
  "Reggae": [0, 0, 0, -5, 0, 6, 6, 0, 0, 0],
  "Rock": [8, 4, -5, -8, -3, 4, 8, 11, 11, 11],
  "Ska": [-2, -4, -4, 0, 4, 5, 8, 9, 11, 9],
  "Soft": [4, 1, 0, -2, 0, 4, 8, 9, 11, 12],
  "Soft Rock": [4, 4, 2, 0, -4, -5, -3, 0, 2, 8],
  "Techno": [8, 5, 0, -5, -4, 0, 8, 9, 9, 8]
}

// Лог-інтерполяція 10-смугового пресета Winamp на 15 смуг mbeq
function toMbeqBands(winampGains) {
  var out = []
  for (var i = 0; i < mbeqBands.length; i++) {
    var f = mbeqBands[i]
    var lf = Math.log(f)
    var g = winampGains[0]
    for (var j = 0; j < winampBands.length - 1; j++) {
      var f0 = Math.log(winampBands[j])
      var f1 = Math.log(winampBands[j + 1])
      if (lf <= f0) { g = winampGains[j]; break }
      if (lf <= f1) {
        var t = (lf - f0) / (f1 - f0)
        g = winampGains[j] + t * (winampGains[j + 1] - winampGains[j])
        break
      }
      g = winampGains[j + 1]
    }
    out.push(Math.round(g * 10) / 10)
  }
  return out
}

// Усі пресети одразу в смугах mbeq: { "Flat": [15 значень], ... }
function all() {
  var out = {}
  for (var name in winampPresets)
    out[name] = toMbeqBands(winampPresets[name])
  return out
}

// Назви смуг для UI (короткі підписи під слайдерами)
var bandLabels = [
  "50", "100", "156", "220", "311", "440", "622", "880",
  "1.2k", "1.7k", "2.5k", "3.5k", "5k", "10k", "20k"
]
