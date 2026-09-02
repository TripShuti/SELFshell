// ============================================================
// quickshell/core/IconResolver.qml — єдиний резолв іконок для всього шела
// ============================================================
import Quickshell
import QtQuick

QtObject {
  property var _cache: ({})

  function resolve(icon) {
    if (!icon) return ""
    var s = String(icon)
    if (_cache[s] !== undefined) return _cache[s]
    var res = _resolveUncached(s)
    var copy = Object.assign({}, _cache)
    copy[s] = res
    _cache = copy
    // обмежуємо кеш щоб не ріс безмежно
    var keys = Object.keys(_cache)
    if (keys.length > 200) {
      var c2 = {}
      for (var i = keys.length - 100; i < keys.length; i++) c2[keys[i]] = _cache[keys[i]]
      _cache = c2
    }
    return res
  }

  function _resolveUncached(icon) {
    var s = String(icon)
    if (s.startsWith("/") || s.startsWith("file://")) return s.startsWith("file://") ? s : "file://" + s
    if (s.startsWith("image://icon/")) {
      var n = s.substring("image://icon/".length)
      if (n === "") return ""
      if (n.startsWith("/")) return "file://" + n
      s = n
    }
    var p = Quickshell.iconPath(s, true)
    if (p !== "") return p
    var low = s.toLowerCase().replace(/\s+/g, "-")
    p = Quickshell.iconPath(low, true)
    if (p !== "") return p
    if (low === "telegram" || low === "org.telegram.messenger" || low.indexOf("telegram") !== -1) {
      p = Quickshell.iconPath("org.telegram.desktop", true)
      if (p !== "") return p
      p = Quickshell.iconPath("telegram-desktop", true)
      if (p !== "") return p
    }
    if (low.indexOf("whatsapp") !== -1) {
      p = Quickshell.iconPath("whatsapp", true)
      if (p !== "") return p
    }
    p = Quickshell.iconPath("org." + low + ".desktop", true)
    if (p !== "") return p
    return ""
  }

  function clearCache() { _cache = {} }
}
