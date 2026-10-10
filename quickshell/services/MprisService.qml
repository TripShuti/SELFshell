// ============================================================
// quickshell/services/MprisService.qml — спільний реактивний вибір MPRIS-плеєра
// ============================================================
import Quickshell.Services.Mpris
import QtQuick

Item {
  id: root
  required property QtObject appConfig
  visible: false

  readonly property var player: {
    var preferred = String(root.appConfig.cfg.preferredPlayer).toLowerCase()
    var players = Mpris.players.values
    var fallback = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!fallback && p.trackTitle) fallback = p
      var name = String(p.identity || p.dbusName || "").toLowerCase()
      if (preferred !== "" && name.indexOf(preferred) >= 0) return p
    }
    return fallback
  }
}
