// ============================================================
// core/PairingAgent.qml — міст між qs-bt-agent і UI парингу.
// Стежить за $XDG_RUNTIME_DIR/selfshell-pairing/request.json
// (пише services/qs-bt-agent), відповідь кладе в response.json.
// Той самий патерн, що last-shot.txt у ControlPopup: обмін
// через FileView, без нових залежностей.
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root
  visible: false

  // Активний запит агента або null. Формат (пише qs-bt-agent):
  //   {id, ts, method, address, passkey?, uuid?}
  //   method: confirm | pin | passkey | authorize | service |
  //           display | displaypin | done
  property var request: null

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") ?? ""
  readonly property bool available: runtimeDir !== ""

  readonly property string _requestPath: available ? "file://" + runtimeDir + "/selfshell-pairing/request.json" : ""
  readonly property string _responsePath: available ? "file://" + runtimeDir + "/selfshell-pairing/response.json" : ""

  Component.onCompleted: root._parse(_requestFile.text())

  FileView {
    id: _requestFile
    path: root._requestPath
    watchChanges: true
    onFileChanged: this.reload()
    onDataChanged: root._parse(this.text())
  }

  FileView {
    id: _responseFile
    path: root._responsePath
  }

  function _parse(text) {
    var data = null
    try {
      data = text ? JSON.parse(text) : null
    } catch (e) {
      data = null
    }
    // Застарілий запис (після рестарту шела посеред запиту) — ігноруємо:
    // агент відповість таймаутом сам
    if (data && data.ts && (Date.now() / 1000 - data.ts > 70))
      data = null
    if (data && (data.method === "done" || data.method === "cancel"))
      data = null
    root.request = data
  }

  // Відповідає агенту на запит id. pin потрібен лише для method=pin/passkey,
  // trust — бажання користувача довірити пристрій після успішного парингу
  // (агент сам поставить Device1.Trusted, коли BlueZ завершить бонд)
  function respond(id, accepted, pin, trust) {
    if (!root.available) return
    _responseFile.setText(JSON.stringify({
      id: id, accepted: accepted, pin: pin || "", trust: trust === true
    }))
  }

  function reject(id) { respond(id, false, "", false) }
}
