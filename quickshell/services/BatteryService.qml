// ============================================================
// quickshell/services/BatteryService.qml — спільний стан батареї та автоматичний профіль живлення
// ============================================================
import Quickshell.Io
import QtQuick

Item {
  id: root
  required property QtObject appConfig
  required property QtObject powerProfiles
  visible: false
  property int percent: -1
  property string state: ""
  property string device: ""
  readonly property bool available: device !== ""

  readonly property bool charging: state === "charging" || state === "pending-charge"
  readonly property bool low: percent >= 0 && percent <= 15 && !root.charging

  // Сповіщення про низький заряд: один раз за цикл розряду (не спамимо
  // кожні 30 с опитування), скидається при зарядці або >= 20%.
  // DND поважається — тост не показується, коли dndEnabled.
  // Гістерезис re-arm і авто-профіль живлення — ті самі пороги.
  property bool lowNotified: false
  readonly property var powerSvc: root.powerProfiles ?? null
  signal lowBattery(int percent)
  function updatePowerState() {
    // Гістерезис: re-arm лише при зарядці або >= 20% — без нього заряд,
    // що коливається біля 15%, спамив би тостом на кожному пересіченні.
    // Тут же повертаємо ручний профіль живлення після авто power-saver.
    if (root.percent >= 20 || root.charging) {
      root.lowNotified = false
      if (root.powerSvc && root.appConfig.cfg.autoPowerSaver) root.powerSvc.restoreManual()
      return
    }
    if (!root.low || root.lowNotified) return
    root.lowNotified = true
    // Авто power-saver — до тоста, щоб профіль встиг перемкнутись навіть у DND
    if (root.powerSvc && root.appConfig.cfg.autoPowerSaver) root.powerSvc.setProfile("power-saver", true)
    if (!root.appConfig.cfg.dndEnabled) root.lowBattery(root.percent)
  }

  function refresh() {
    if (!devsProc.running && !infoProc.running) devsProc.running = true
  }
  Timer {
    interval: 30000
    repeat: true
    triggeredOnStart: true
    running: root.appConfig.cfg.batteryEnabled
    onTriggered: root.refresh()
  }
  Process {
    id: devsProc
    command: ["upower", "-e"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.trim().split(/\r?\n/)
        var device = ""
        for (var i = 0; i < lines.length; i++) {
          if (/battery/i.test(lines[i])) { device = lines[i]; break }
        }
        root.device = device
        if (device === "") return
        infoProc.command = ["upower", "-i", device]
        infoProc.running = true
      }
    }
  }
  Process {
    id: infoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyInfo(text)
    }
  }
  function applyInfo(text) {
    var lines = String(text).split(/\r?\n/)
    var percent = -1
    var state = ""
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([a-z]+)\s*:\s*(.+?)\s*$/)
      if (!m) continue
      if (m[1] === "percentage") percent = parseInt(m[2], 10)
      else if (m[1] === "state") state = m[2]
    }
    if (!isFinite(percent) || percent < 0 || state === "") return
    root.state = state
    root.percent = percent
    root.updatePowerState()
  }
}
