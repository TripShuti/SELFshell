// ============================================================
// quickshell/popups/settings/SystemSection.qml — розділ System: профіль живлення (power-profiles-daemon), авто power-saver та оновлення пакетів
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
  readonly property var pacmanSvc: window.pacmanUpdates ?? null

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  // оновлення стану при кожному відкритті (патерн SettingsPopup resync)
  function resync() {
    if (root.powerSvc) root.powerSvc.refresh()
    govFile.reload()
    eppFile.reload()
    root.refreshSysInfo()
  }
  Component.onCompleted: root.resync()

  // --- Міні-моніторинг (scripts/sysinfo.py, тільки читання) ---
  readonly property string sysinfoScript: Qt.resolvedUrl("../../scripts/sysinfo.py").toString().replace("file://", "")
  property var sysInfo: null
  function refreshSysInfo() {
    if (infoProc.running) return
    infoProc.command = ["python3", root.sysinfoScript]
    infoProc.running = true
  }
  Process {
    id: infoProc
    stdout: StdioCollector {
      id: infoOut
      waitForEnd: true
      onStreamFinished: {
        try {
          root.sysInfo = JSON.parse(String(infoOut.text ?? "").trim())
        } catch (e) { root.sysInfo = null }
      }
    }
    onExited: running = false
  }
  // живе оновлення поки відкриті налаштування (секція живе лише на активній вкладці)
  Timer {
    interval: 5000
    running: root.sys.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshSysInfo()
  }
  function fmtCpu() {
    var t = root.sysInfo ? root.sysInfo.cpu_temp_c : null
    var m = root.sysInfo ? root.sysInfo.cpu_mhz : null
    if (t == null && m == null) return "—"
    var parts = []
    if (t != null) parts.push((Math.round(t * 10) / 10) + "°C")
    if (m != null) parts.push((Math.round(m / 100) / 10) + " GHz")
    return parts.join(" · ")
  }
  function fmtMem() {
    if (!root.sysInfo || root.sysInfo.mem_used_pct == null) return "—"
    return root.sysInfo.mem_used_gb + " / " + root.sysInfo.mem_total_gb + " GB (" + root.sysInfo.mem_used_pct + "%)"
  }

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

  // --- Оновлення пакетів: весь стан живе в PacmanService-синглтоні, секція
  // лише відображає (чек тут НЕ запускається — ні при відкритті, ні в resync) ---
  readonly property string updatesStatus: {
    var s = root.pacmanSvc
    if (!s) return ""
    if (!s.available) return s.error !== "" ? s.error : "Update service unavailable"
    if (s.upgrading) return "Upgrading in terminal… the list refreshes when done."
    if (s.checking) return "Checking for updates…"
    if (s.error !== "") return s.error
    if (s.count === 0) return "Up to date · checked " + s.lastCheckText()
    // розбивку repo/AUR показуємо лише коли є AUR — інакше "20 updates (20 repo)" тавтологія
    var parts = s.count + " updates"
    if (s.aurCount > 0) parts += " (" + s.repoCount + " official + " + s.aurCount + " AUR)"
    if (s.totalDownload !== "") parts += " · ↓ " + s.totalDownload
    return parts + " · checked " + s.lastCheckText()
  }
  readonly property var visiblePkgs: {
    var s = root.pacmanSvc
    if (!s || !s.available) return []
    return s.packages.slice(0, 30)
  }
  readonly property int hiddenPkgCount: {
    var s = root.pacmanSvc
    if (!s || !s.available) return 0
    return Math.max(0, s.count - 30)
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
        // опції з фактично доступних тут (парс `powerprofilesctl list` при
        // старті сервісу); тексти фіксовані — id з вайтлиста, ін'єкції нема
        options: {
          var names = root.powerSvc ? root.powerSvc.profiles : []
          var titles = { performance: "Performance", balanced: "Balanced", "power-saver": "Power saver" }
          var out = []
          for (var i = 0; i < names.length; i++)
            if (titles[names[i]] !== undefined) out.push({ id: names[i], text: titles[names[i]] })
          return out
        }
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
        onToggled: function(v) {
          root.cfg.autoPowerSaver = v
          root.ac.saveToFile()
          // вимкнення автоматики повертає ручний профіль одразу
          if (!v && root.powerSvc) root.powerSvc.restoreManual()
        }
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Updates" }
      Text {
        text: root.updatesStatus
        color: window.palette.mutedAlt
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        SetButton {
          sys: root.sys
          text: (root.pacmanSvc && root.pacmanSvc.checking) ? "Checking…" : "Check for updates"
          disabled: !root.pacmanSvc || root.pacmanSvc.checking || root.pacmanSvc.upgrading
          onClicked: if (root.pacmanSvc) root.pacmanSvc.refresh()
        }
        SetButton {
          sys: root.sys
          text: (root.pacmanSvc && root.pacmanSvc.upgrading) ? "Updating…" : "Update all"
          disabled: !root.pacmanSvc || !root.pacmanSvc.available || root.pacmanSvc.checking || root.pacmanSvc.upgrading || root.pacmanSvc.count === 0
          onClicked: {
            if (!root.pacmanSvc) return
            root.pacmanSvc.startUpgrade()
            // термінал вже летить — гасимо налаштування з анімацією,
            // щоб перехід виглядав безшовно (стан апгрейда живе в сервісі)
            root.sys.close()
          }
        }
      }
      // без хелпера AUR-рядків не буде взагалі — чесно показуємо межу скоупу
      Text {
        visible: root.pacmanSvc && root.pacmanSvc.available && root.pacmanSvc.helper === ""
        text: "No AUR helper (yay/paru) — repo packages only."
        color: window.palette.mutedAlt
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }
      Repeater {
        model: root.visiblePkgs
        delegate: UpdateRow {
          required property var modelData
          pkgName: modelData.name ?? ""
          verText: (modelData.old ?? "") + " → " + (modelData.new ?? "")
          repoText: modelData.repo ?? ""
        }
      }
      Text {
        visible: root.hiddenPkgCount > 0
        text: "+" + root.hiddenPkgCount + " more"
        color: window.palette.mutedAlt
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Monitoring" }
      MonitorRow { label: "CPU"; value: root.fmtCpu(); frac: -1 }
      MonitorRow {
        label: "Memory"
        value: root.fmtMem()
        frac: root.sysInfo && root.sysInfo.mem_used_pct != null ? root.sysInfo.mem_used_pct / 100 : -1
      }
      Repeater {
        model: root.sysInfo && root.sysInfo.disks ? root.sysInfo.disks : []
        delegate: MonitorRow {
          required property var modelData
          label: "Disk " + modelData.mount
          value: modelData.free_gb + " / " + modelData.total_gb + " GB free (" + modelData.used_pct + "%)"
          frac: modelData.used_pct / 100
        }
      }
    }
  }

  // Рядок списку оновлень: ім'я + перехід версій + тег репозиторію
  component UpdateRow: RowLayout {
    id: urow
    property string pkgName: ""
    property string verText: ""
    property string repoText: ""
    Layout.fillWidth: true
    spacing: 8
    Text {
      text: urow.pkgName
      color: window.palette.fg
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      Layout.fillWidth: true
      elide: Text.ElideRight
    }
    Text {
      visible: urow.repoText !== ""
      text: urow.repoText
      color: window.palette.accent
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(9)
    }
    Text {
      text: urow.verText
      color: window.palette.mutedAlt
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(10)
      elide: Text.ElideRight
    }
  }

  // Рядок моніторингу: підпис + значення + тонка смужка (frac < 0 — без смужки)
  component MonitorRow: ColumnLayout {
    id: mrow
    property string label: ""
    property string value: ""
    property real frac: -1
    Layout.fillWidth: true
    spacing: 2
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: mrow.label
        color: window.palette.gray
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
        Layout.preferredWidth: 64
        elide: Text.ElideRight
      }
      Item { Layout.fillWidth: true }
      Text {
        text: mrow.value
        color: window.palette.fg
        font.family: window.palette.font
        font.pixelSize: window.appConfig.scaled(10)
      }
    }
    Rectangle {
      visible: mrow.frac >= 0
      Layout.fillWidth: true
      implicitHeight: 4
      radius: 2
      color: window.palette.bg2
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, mrow.frac))
        height: parent.height
        radius: parent.radius
        color: mrow.frac > 0.9 ? window.palette.danger : window.palette.accent
      }
    }
  }
}
