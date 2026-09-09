// ============================================================
// quickshell/services/PacmanService.qml — оновлення пакетів: кешований список checkupdates + AUR, daily-перевірка, стан апгрейда
// ============================================================
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Єдиний власник стану оновлень: дорогий мережевий чек виконується ТІЛЬКИ
// тут — при старті (якщо кеш старший за добу), раз на добу таймером та по
// кнопці. Секція System лише читає властивості, resync() нічого не запускає.
// Апгрейд іде у зовнішньому терміналі (sudo питає пароль там же); момент
// завершення ловимо через sentinel-файл від scripts/pacman_upgrade.sh,
// закриття вікна — через вихід owned-процеса kitty (покриває раннє закриття).
Item {
  id: root
  visible: false

  property var packages: []
  property int repoCount: 0
  property int aurCount: 0
  property string helper: ""
  property string totalDownload: ""
  // true після першого вдалого чеку або завантаженого кешу; false лише коли
  // нема checkupdates (тоді error несе підказку про pacman-contrib)
  property bool available: false
  property bool checking: false
  property string error: ""
  property double lastCheck: 0
  property bool upgrading: false

  readonly property int count: root.packages.length
  readonly property string checkScript: Qt.resolvedUrl("../scripts/pacman_updates.py").toString().replace("file://", "")
  readonly property string upgradeScript: Qt.resolvedUrl("../scripts/pacman_upgrade.sh").toString().replace("file://", "")
  readonly property string runtimeBase: {
    var r = String(Quickshell.env("XDG_RUNTIME_DIR") ?? "")
    return r !== "" ? r : "/tmp"
  }
  property string sentinelPath: ""

  function needsRefresh() {
    if (root.lastCheck <= 0) return true
    return (Date.now() / 1000 - root.lastCheck) > 24 * 3600
  }

  function lastCheckText() {
    if (root.lastCheck <= 0) return "Never checked"
    var age = Date.now() / 1000 - root.lastCheck
    if (age < 90) return "Just now"
    if (age < 3600) return Math.floor(age / 60) + "m ago"
    if (age < 24 * 3600) return Math.floor(age / 3600) + "h ago"
    return Qt.formatDate(new Date(root.lastCheck * 1000), "dd MMM")
  }

  function refresh() {
    if (root.checking || checkProc.running) return
    root.checking = true
    root.error = ""
    checkProc.command = ["python3", root.checkScript]
    checkProc.running = true
  }

  function startUpgrade() {
    if (root.upgrading || !root.available || root.count === 0) return
    // унікальний шлях на запуск — старі sentinel не плутаються з поточним,
    // чистити нічого не треба (враппер сам тре старі done-* на старті)
    root.sentinelPath = root.runtimeBase + "/selfshell-upgrade/done-" + Math.floor(Date.now() / 1000)
    sentinelFile.path = "file://" + root.sentinelPath
    root.upgrading = true
    // фіксований title ловить windowrule selfshell-upgrade-float
    // (hypr/modules/rules.lua): вікно пливе по центру, а не тайлиться
    upgradeProc.command = ["kitty", "--title", "SELFshell Update", "-e", root.upgradeScript, root.sentinelPath]
    upgradeProc.running = true
    upgradeTimeout.restart()
    // вікно мапиться з затримкою, а закриття попапа з grabFocus може
    // повернути фокус старому вікну — тому фокусуємо термінал явно
    focusTimer.restart()
  }

  function _applyCheck(text) {
    var data = null
    try {
      data = JSON.parse(String(text ?? "").trim())
    } catch (e) {
      data = null
    }
    if (!data) {
      root.error = "Update check failed"
      return
    }
    if (data.missing_checkupdates) {
      root.available = false
      root.error = "checkupdates not found — pacman -S pacman-contrib"
      return
    }
    if (!data.ok) {
      root.available = true
      root.error = String(data.error ?? "Update check failed")
      return
    }
    root.available = true
    root.error = ""
    root.packages = data.packages ?? []
    root.repoCount = data.repo_count ?? 0
    root.aurCount = data.aur_count ?? 0
    root.helper = String(data.helper ?? "")
    root.totalDownload = String(data.total_download ?? "")
    root.lastCheck = Date.now() / 1000
    root._saveCache()
  }

  function _saveCache() {
    cacheFile.setText(JSON.stringify({
      lastCheck: root.lastCheck,
      packages: root.packages,
      repoCount: root.repoCount,
      aurCount: root.aurCount,
      helper: root.helper,
      totalDownload: root.totalDownload
    }))
  }

  function _loadCache() {
    var data = null
    try {
      data = JSON.parse(cacheFile.text())
    } catch (e) {
      data = null
    }
    if (!data || !(data.packages instanceof Array)) return
    root.packages = data.packages
    root.repoCount = data.repoCount ?? 0
    root.aurCount = data.aurCount ?? 0
    root.helper = String(data.helper ?? "")
    root.totalDownload = String(data.totalDownload ?? "")
    root.lastCheck = data.lastCheck ?? 0
    root.available = true
  }

  // Поява sentinel = враппер допрацював (успіх чи ні — покаже перечек):
  // гасимо upgrading і один раз перечитуємо список, термінал лишається
  // відкритим з паузою, щоб було видно підсумок
  function _onSentinelSeen() {
    if (!root.upgrading) return
    root.upgrading = false
    upgradeTimeout.stop()
    root.refresh()
  }

  Process {
    id: checkProc
    stdout: StdioCollector {
      id: checkOut
      waitForEnd: true
      onStreamFinished: root._applyCheck(checkOut.text)
    }
    onExited: (code) => {
      running = false
      root.checking = false
    }
  }

  Process {
    id: upgradeProc
    onExited: (code) => {
      running = false
      upgradeTimeout.stop()
      // раннє закриття вікна (sentinel нема) — теж привід перечитати:
      // список покаже чесний залишок
      if (root.upgrading) {
        root.upgrading = false
        root.refresh()
      }
    }
  }

  // явний фокус на вікно апгрейда: спрацьовує після мапінгу вікна.
  // Виклик — через Quickshell Hyprland.dispatch з Lua-синтаксисом
  // (канон WorkspacesWidget): класичний `hyprctl dispatch focuswindow ...`
  // цей Hyprland загортає в hl.dispatch(...) і він не парситься
  Timer {
    id: focusTimer
    interval: 700
    onTriggered: {
      // термінал могли закрити раніше — тоді фокус не чіпаємо
      if (!root.upgrading) return
      Hyprland.dispatch("hl.dsp.focus({ window = \"title:^SELFshell Update$\" })")
    }
  }

  FileView {
    id: cacheFile
    path: Qt.resolvedUrl("../data/updates.json")
    watchChanges: false
    printErrors: false
    onLoaded: root._loadCache()
    onLoadFailed: function() {}
  }

  FileView {
    id: sentinelFile
    // реальний шлях підставляє startUpgrade(); до того — нейтральний,
    // щоб створення компонента не залежало від дефолтного path
    path: "file:///dev/null"
    watchChanges: false
    printErrors: false
    onLoaded: {
      if (String(sentinelFile.text() ?? "").trim() !== "") root._onSentinelSeen()
    }
    onLoadFailed: function() {}
  }

  // опитування sentinel — лише поки іде апгрейд (локальний файл, без мережі)
  Timer {
    id: sentinelTimer
    interval: 3000
    repeat: true
    running: root.upgrading && root.sentinelPath !== ""
    onTriggered: sentinelFile.reload()
  }

  // страховка від завислого "Updating…", якщо термінал убили разом із шелом
  Timer {
    id: upgradeTimeout
    interval: 30 * 60 * 1000
    onTriggered: root.upgrading = false
  }

  // відкладений стартовий чек — не гальмуємо завантаження шела мережею
  Timer {
    id: startupTimer
    interval: 60000
    onTriggered: {
      if (root.needsRefresh() && !root.upgrading) root.refresh()
    }
  }

  Timer {
    id: dailyTimer
    interval: 24 * 3600 * 1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: {
      if (!root.upgrading) root.refresh()
    }
  }

  Component.onCompleted: startupTimer.start()
}
