// ============================================================
// quickshell/services/PowerProfileService.qml — профілі живлення через power-profiles-daemon: active, set, авто-повернення
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick

// Єдиний власник стану живлення: читає `powerprofilesctl get`, перемикає
// `powerprofilesctl set` (масив argv, профіль з фіксованого enum — ін'єкції
// нема за конструкцією, root не потрібен). Живе один інстанс в shell.qml,
// прокидається в Bar через window.powerProfiles.
Item {
  id: root
  visible: false

  readonly property var profiles: ["performance", "balanced", "power-saver"]
  // активний профіль ("" = невідомо/демон недоступний)
  property string profile: ""
  property bool available: false
  property bool busy: false
  property string error: ""
  // останній ручний вибір (для повернення після авто power-saver)
  property string lastManualProfile: ""
  // true коли поточний power-saver виставила автоматика, а не людина
  property bool autoActive: false

  function refresh() {
    if (getProc.running) return
    getProc.command = ["powerprofilesctl", "get"]
    getProc.running = true
  }

  // isAuto=true — виклик від автоматики (батарея), не чіпає lastManual
  function setProfile(name, isAuto) {
    if (profiles.indexOf(name) === -1) return
    if (setProc.running) return
    root.error = ""
    root.busy = true
    setProc._want = name
    setProc._wantAuto = isAuto === true
    setProc.command = ["powerprofilesctl", "set", name]
    setProc.running = true
  }

  // повертає ручний профіль після авто power-saver (no-op якщо авто не активне)
  function restoreManual() {
    if (!root.autoActive || root.lastManualProfile === "") return
    root.setProfile(root.lastManualProfile, false)
  }

  Process {
    id: getProc
    stdout: StdioCollector {
      id: getOut
      waitForEnd: true
      onStreamFinished: {
        var t = String(getOut.text ?? "").trim()
        if (root.profiles.indexOf(t) !== -1) {
          root.profile = t
          root.available = true
          if (root.lastManualProfile === "") root.lastManualProfile = t
        } else {
          root.available = false
        }
      }
    }
    onExited: (code) => {
      running = false
      if (code !== 0) root.available = false
    }
  }

  Process {
    id: setProc
    property string _want: ""
    property bool _wantAuto: false
    onExited: (code) => {
      running = false
      root.busy = false
      if (code !== 0) {
        root.error = "powerprofilesctl set failed (" + code + ")"
        return
      }
      root.profile = setProc._want
      root.available = true
      if (setProc._wantAuto) {
        root.autoActive = true
      } else {
        root.autoActive = false
        root.lastManualProfile = setProc._want
      }
    }
  }

  Component.onCompleted: root.refresh()
}
