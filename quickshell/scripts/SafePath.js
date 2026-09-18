// ============================================================
// quickshell/scripts/SafePath.js — предикати безпечних шляхів для allowlist-відкриттів
// ============================================================
.pragma library

// Строгий префікс: path лежить всередині dir або збігається з ним.
// Порожні/відносні шляхи та ".." відхиляються завжди (обхід нагору
// через xdg-open/Image). Кінцевий слеш dir зрізається всередині,
// тому "includes"-матчі на кшталт /tmp/Downloads/kcd/* не проходять.
function isWithinDir(path, dir) {
  var p = String(path ?? "")
  var d = String(dir ?? "").replace(/\/$/, "")
  if (p === "" || d === "" || p[0] !== "/" || p.includes("..")) return false
  return p === d || p.startsWith(d + "/")
}

// Той самий предикат проти списку тек (порожні записи ігноруються)
function isWithinAnyDir(path, dirs) {
  var list = dirs || []
  for (var i = 0; i < list.length; i++)
    if (isWithinDir(path, list[i])) return true
  return false
}

// Нормалізація тексту для порівнянь: trim + схлопування пробілів.
// Без lower: регістр додає викликач, якщо того вимагає матч (див. Bar).
function norm(s) {
  return String(s ?? "").trim().replace(/\s+/g, " ")
}
