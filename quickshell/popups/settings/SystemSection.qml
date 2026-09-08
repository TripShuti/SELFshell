// ============================================================
// quickshell/popups/settings/SystemSection.qml — розділ System: профіль живлення (power-profiles-daemon) та авто power-saver
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var cfg: sys.cfg
  readonly property var ac: sys.ac
  readonly property var window: sys.window
  readonly property var powerSvc: window.powerProfiles ?? null

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  // оновлення стану при кожному відкритті (патерн SettingsPopup resync)
  function resync() {
    if (root.powerSvc) root.powerSvc.refresh()
    govFile.reload()
    eppFile.reload()
  }
  Component.onCompleted: root.resync()

  // Поточні governor/EPP з sysfs (тільки читання, запису нема — всім керує PPD)
  FileView {
    id: govFile
    path: "file:///sys/devices/system/cpu/cpufreq/policy0/scaling_governor"
    watchChanges: false
    printErrors: false
    onLoadFailed: function() {}
  }
  FileView {
    id: eppFile
    path: "file:///sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference"
    watchChanges: false
    printErrors: false
    onLoadFailed: function() {}
  }
  readonly property string hwInfo: {
    var g = String(govFile.text() ?? "").trim()
    var e = String(eppFile.text() ?? "").trim()
    if (g === "" && e === "") return ""
    if (g !== "" && e !== "") return "governor " + g + " · epp " + e
    return g !== "" ? "governor " + g : "epp " + e
  }

  readonly property string statusText: {
    if (!root.powerSvc || !root.powerSvc.available) return "power-profiles-daemon unavailable — systemctl enable --now power-profiles-daemon"
    if (root.powerSvc.error !== "") return root.powerSvc.error
    if (root.powerSvc.busy) return "Applying…"
    var p = root.powerSvc.profile !== "" ? root.powerSvc.profile : "unknown"
    var auto = root.powerSvc.autoActive ? " (auto power-saver)" : ""
    return "Active: " + p + auto
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 16

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Power" }
      SetSelect {
        sys: root.sys
        label: "Power profile"
        options: [
          { id: "performance", text: "Performance" },
          { id: "balanced", text: "Balanced" },
          { id: "power-saver", text: "Power saver" }
        ]
        value: root.powerSvc ? root.powerSvc.profile : ""
        enabled: root.powerSvc && root.powerSvc.available && !root.powerSvc.busy
        onPicked: id => { if (root.powerSvc) root.powerSvc.setProfile(id, false) }
      }
      Text {
        text: root.statusText + (root.hwInfo !== "" ? "\n" + root.hwInfo : "")
        color: window.palette.mutedAlt
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Automatic" }
      SetToggle {
        sys: root.sys
        label: "Auto power-saver on battery"
        sub: "Drops to power-saver at low battery (≤15%), restores your profile on charge."
        on: root.cfg.autoPowerSaver
        onToggled: v => {
          root.cfg.autoPowerSaver = v
          root.ac.saveToFile()
          // вимкнення автоматики повертає ручний профіль одразу
          if (!v && root.powerSvc) root.powerSvc.restoreManual()
        }
      }
    }
  }
}
