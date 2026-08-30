// ============================================================
// quickshell/core/IconResolver.qml — єдиний резолв іконок для всього шела
// ============================================================
import Quickshell
import QtQuick

QtObject {
  function resolve(icon) {
    if (!icon) return ""
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
}
